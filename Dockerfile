FROM maven:3.6-jdk-11-slim AS build
COPY . .
WORKDIR .
RUN mvn clean package -Popenshift
FROM jboss/wildfly
RUN /opt/jboss/wildfly/bin/add-user.sh admin Admin#70365 --silent
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
COPY --from=build /target/ROOT.war /opt/jboss/wildfly/standalone/deployments/ROOT.war
