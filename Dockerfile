FROM maven:3.6-jdk-11-slim as BUILD
COPY . /src
WORKDIR /src
FROM registry.access.redhat.com/openjdk/openjdk-11-rhel7
FROM wildfly/wildfly-runtime-centos7:17
COPY --from=wildflytest:latest /s2i-output/server $JBOSS_HOME
USER root
RUN chown -R jboss:root $JBOSS_HOME && chmod -R ug+rwX $JBOSS_HOME
RUN ln -s $JBOSS_HOME /wildfly
USER jboss
CMD $JBOSS_HOME/bin/openshift-launch.sh
mvn clean package -Popenshift
ENV JAVA_APP_WAR target/ROOT.war
ENV AB_OFF true
EXPOSE 8080
ADD $JAVA_APP_WAR /opt/wildfly/standalone/deployments/
