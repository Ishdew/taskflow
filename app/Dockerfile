# Multi-stage Dockerfile for TaskFlow.
# Build with Maven, then run with a lightweight JRE image.

# ----- build ------------------------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-21-alpine AS build

WORKDIR /workspace

# Copy pom first so dependencies can be cached.
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -DskipTests dependency:go-offline

COPY src ./src
# Build the app and extract the Spring Boot layers.
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -DskipTests package \
 && java -Djarmode=tools -jar target/taskflow.jar extract \
        --layers --launcher --destination extracted

# ----- runtime ----------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine AS runtime

# curl is only used for the health check. Upgrade packages so Trivy does not
# flag known HIGH CVEs in the base image (e.g. openssl).
RUN apk upgrade --no-cache \
 && apk add --no-cache curl \
 && addgroup -S -g 10001 taskflow \
 && adduser -S -u 10001 -G taskflow taskflow

WORKDIR /app

# Copy layers seperately so uncahnged dependencies can be reused.
COPY --from=build --chown=taskflow:taskflow /workspace/extracted/dependencies/ ./
COPY --from=build --chown=taskflow:taskflow /workspace/extracted/spring-boot-loader/ ./
COPY --from=build --chown=taskflow:taskflow /workspace/extracted/snapshot-dependencies/ ./
COPY --from=build --chown=taskflow:taskflow /workspace/extracted/application/ ./

#Run as a non-root user.
USER taskflow

EXPOSE 8080

# Let the JVM adjust heap size based on the container memory.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

# Check if the app is alive without depending on the database.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/health/liveness >/dev/null || exit 1

# Run Java directly so ECS can handle shutdown gracefully.
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
