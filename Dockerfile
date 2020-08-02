FROM maven:3.6-jdk-11-slim as BUILD
COPY . /src
WORKDIR /src
RUN mvn clean package -Popenshift
FROM registry.access.redhat.com/openjdk/openjdk-11-rhel7
FROM jboss/wildfly
ENV JAVA_APP_WAR target/ROOT.war
ENV AB_OFF true
EXPOSE 8080
ADD $JAVA_APP_WAR /opt/jboss/wildfly/standalone/deployments/ 
