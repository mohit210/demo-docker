# syntax=docker/dockerfile:1

# Build the executable Spring Boot JAR.
FROM eclipse-temurin:21-jdk-jammy AS build

WORKDIR /workspace

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

COPY src/ src/
RUN ./mvnw clean package -DskipTests -B \
    && cp target/demo-docker-*.jar application.jar

# Run the application with only the Java runtime.
FROM eclipse-temurin:21-jre-jammy AS runtime

WORKDIR /app

RUN groupadd --system spring \
    && useradd --system --gid spring --home-dir /app --no-create-home spring

COPY --from=build --chown=spring:spring /workspace/application.jar application.jar

USER spring:spring

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/application.jar"]
