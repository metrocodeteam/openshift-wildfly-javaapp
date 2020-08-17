FROM maven:3.6-jdk-11-slim AS build
COPY . .
WORKDIR .
RUN mvn clean package -Popenshift
FROM jboss/wildfly
ENV WILDFLY_USER admin
ENV WILDFLY_PASS Admin#70365
ENV JBOSS_CLI /opt/jboss/wildfly/bin/jboss-cli.sh
ENV DEPLOYMENT_DIR /opt/jboss/wildfly/standalone/deployments/
ENV JBOSS_HOME /opt/jboss/wildfly
ENV LAUNCH_JBOSS_IN_BACKGROUND true
#COPY standalone.xml /opt/jboss/wildfly/standalone/configuration/
RUN echo "=> Adding WildFly administrator"
RUN $JBOSS_HOME/bin/add-user.sh -u $WILDFLY_USER -p $WILDFLY_PASS --silent
RUN echo "=> Starting WildFly server" && \
      bash -c '$JBOSS_HOME/bin/standalone.sh &' && \
    echo "=> Waiting for the server to boot" && \
      bash -c 'until `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null | grep -q running`; do echo `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null`; sleep 1; done' && \
    echo "=> Shutting down WildFly and Cleaning up" && \
      $JBOSS_CLI --connect --command=":shutdown" && \
    rm -rf $JBOSS_HOME/standalone/configuration/standalone_xml_history/ $JBOSS_HOME/standalone/log/* && \
      rm -f /tmp/*.jar
USER 1000
EXPOSE 8080 9990
#RUN touch /opt/jboss/wildfly/standalone/data/content/tmp.txt
#echo "=> Restarting WildFly"
# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interfaces
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
COPY --from=build /target/ROOT.war /opt/jboss/wildfly/standalone/deployments/ROOT.war
