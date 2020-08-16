#
# Officially supported Zulu JDK
#
# For support or general questions go to:
#
# https://support.microsoft.com/en-us/help/4026305/sql-contact-microsoft-azure-support
#
FROM mcr.microsoft.com/java/jdk:8u242-zulu-centos

# Install packages necessary to run WildFly
RUN yum update -y && yum -y install bsdtar unzip && yum clean all

USER root

# Create a user and group used to launch processes
# The user ID 1000 is the default for the first "regular" user on Fedora/RHEL,
# so there is a high chance that this ID will be equal to the current user
# making it easier to use volumes (no permission issues)
RUN groupadd -r jboss -g 1000 && useradd -u 1000 -r -g jboss -m -d /opt/jboss -s /sbin/nologin -c "JBoss user" jboss && \
    chmod 755 /opt/jboss

# Set the working directory to jboss' user home directory
WORKDIR /opt/jboss

# Specify the user which should be used to execute all commands below
USER jboss

# Appserver
ENV WILDFLY_USER admin
ENV WILDFLY_PASS adminPassword

# Database
ENV DB_NAME bdr-itwv-db-1.dev.uspto.gov
ENV DB_USER bdr_admin
ENV DB_PASS ChangeMe_123
ENV DB_URI ptab:3306

ENV MYSQL_VERSION 5.1.36



# Set the WILDFLY_VERSION env variable
ENV WILDFLY_VERSION 18.0.1.Final
ENV WILDFLY_SHA1 ef0372589a0f08c36b15360fe7291721a7e3f7d9
ENV JBOSS_HOME /opt/jboss/wildfly

# Set the root for install
USER root

# Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# Make sure the distribution is available from a well-known place

RUN cd $HOME \
    && curl -O https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz \
    && sha1sum wildfly-$WILDFLY_VERSION.tar.gz | grep $WILDFLY_SHA1 \
    && tar xf wildfly-$WILDFLY_VERSION.tar.gz \
    && mv $HOME/wildfly-$WILDFLY_VERSION $JBOSS_HOME \
    && rm wildfly-$WILDFLY_VERSION.tar.gz \
    && chown -R jboss:0 ${JBOSS_HOME} \
    && chmod -R g+rw ${JBOSS_HOME}

# Configure Wildfly server
ENV JBOSS_CLI /opt/jboss/wildfly/bin/jboss-cli.sh
ENV DEPLOYMENT_DIR /opt/jboss/wildfly/standalone/deployments/
RUN echo "=> Adding WildFly administrator"
RUN $JBOSS_HOME/bin/add-user.sh -u $WILDFLY_USER -p $WILDFLY_PASS --silent


RUN echo "=> Starting WildFly server" && \
      bash -c '$JBOSS_HOME/bin/standalone.sh &' && \
    echo "=> Waiting for the server to boot" && \
      bash -c 'until `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null | grep -q running`; do echo `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null`; sleep 1; done' && \
    echo "=> Downloading MySQL driver" && \
      curl --location --output /tmp/mysql-connector-java-${MYSQL_VERSION}.jar --url http://search.maven.org/remotecontent?filepath=mysql/mysql-connector-java/${MYSQL_VERSION}/mysql-connector-java-${MYSQL_VERSION}.jar && \
    echo "=> Adding MySQL module" && \
    echo "=> Shutting down WildFly and Cleaning up" && \
      $JBOSS_CLI --connect --command=":shutdown" && \
      rm -rf $JBOSS_HOME/standalone/configuration/standalone_xml_history/ $JBOSS_HOME/standalone/log/* && \
      rm -f /tmp/*.jar

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown
ENV LAUNCH_JBOSS_IN_BACKGROUND true

# Set the current user for JBoss process
USER 1000
EXPOSE 8080 9990


# Expose the ports we're interested in

# Make Java 8 obey container resource limits, improve performance
ENV JAVA_OPTS "-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:+UseG1GC -Djava.awt.headless=true"

# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interface
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
COPY  target/ROOT.war /opt/jboss/wildfly/standalone/deployments/ROOT.war
