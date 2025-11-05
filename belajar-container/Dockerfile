FROM amazoncorretto:25-alpine
ADD target/belajar-container-0.0.1-SNAPSHOT.jar /opt/app.jar
RUN sh -c 'touch /opt/app.jar'
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/opt/app.jar"]