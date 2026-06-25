FROM maven:3.9-eclipse-temurin-11@sha256:f580cae20128b75c984853630c054baf486a8c2f345a7d47692ca8b3b5b775d9 AS build
WORKDIR /build

COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B clean package -DskipTests

RUN java -Djarmode=layertools -jar target/*.jar extract --destination extracted

RUN jlink \
    --add-modules java.base,java.logging,java.xml,java.naming,java.management,java.instrument,java.sql,java.desktop,java.net.http,java.security.jgss,java.security.sasl,java.compiler,java.scripting,java.transaction.xa,java.rmi,jdk.unsupported,jdk.crypto.ec,jdk.jfr \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=2 \
    --output /javaruntime

FROM debian:bookworm-slim@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df AS runtime
WORKDIR /app

ENV JAVA_HOME=/opt/java
ENV PATH="${JAVA_HOME}/bin:${PATH}"
COPY --from=build /javaruntime ${JAVA_HOME}

RUN groupadd -r -g 10001 spring && useradd -r -u 10001 -g spring spring
USER 10001:10001

COPY --from=build --chown=spring:spring /build/extracted/dependencies/ ./
COPY --from=build --chown=spring:spring /build/extracted/spring-boot-loader/ ./
COPY --from=build --chown=spring:spring /build/extracted/snapshot-dependencies/ ./
COPY --from=build --chown=spring:spring /build/extracted/application/ ./

EXPOSE 9001

ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
