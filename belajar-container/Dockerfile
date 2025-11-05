# Tahap 1 : Compile dan Build
FROM maven:3-amazoncorretto-25-alpine AS builder
# membuat working folder
WORKDIR /opt/aplikasi
# menambahkan pom.xml dari laptop ke dalam container
COPY pom.xml .
# donlod dependensi dulu, supaya menjadi layer terpisah dari compile
RUN mvn dependency:go-offline
# menambahkan folder src ke dalam container
COPY src ./src
# menjalankan compile source code dan buat jar file
RUN mvn package -DskipTests

# Tahap 2 : Extract menjadi layer-layer
FROM amazoncorretto:25-alpine AS jarlayer
WORKDIR /builder
COPY --from=builder /opt/aplikasi/target/*.jar application.jar
RUN java -Djarmode=tools -jar application.jar extract --layers --destination extracted

# Tahap 3 : Build final image
FROM amazoncorretto:25-alpine
WORKDIR /application
COPY --from=jarlayer /builder/extracted/dependencies/ ./
COPY --from=jarlayer /builder/extracted/spring-boot-loader/ ./
COPY --from=jarlayer /builder/extracted/snapshot-dependencies/ ./
COPY --from=jarlayer /builder/extracted/application/ ./
ENTRYPOINT ["java", "-jar", "application.jar"]
