# Stage 1
FROM maven:3.8-amazoncorretto-8@sha256:638a08a7693cb108e1a78098da48d19c4f5eed9ac857a9d66217d0cd6f5414a3 AS build

WORKDIR /build

# pom.xml first to cache dependency layer
COPY backend/pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build JAR
COPY backend/src ./src
RUN mvn package -DskipTests -B && \
    mv target/interview-1.0-SNAPSHOT.jar target/app.jar

# Stage 2
FROM amazoncorretto:8u412-al2023-jre

# Non-root user with explicit UID/GID (must match Helm podSecurityContext)
RUN groupadd -g 1000 appgroup && useradd -u 1000 -g appgroup -d /app -s /usr/sbin/nologin appuser

WORKDIR /app

# Create tmp dir for Spring Boot (needed if readOnlyRootFilesystem is enabled in K8s)
RUN mkdir -p /app/tmp && chown appuser:appgroup /app/tmp

COPY --from=build --chown=appuser:appgroup /build/target/app.jar ./app.jar

USER appuser

EXPOSE 8080

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -Djava.io.tmpdir=/app/tmp"

# exec replaces the shell so the JVM becomes PID 1 and receives SIGTERM directly
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
