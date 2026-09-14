FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y mariadb-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/mysqld && \
    chown -R mysql:mysql /run/mysqld
    
COPY ./entry/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3306

ENTRYPOINT [ "/entrypoint.sh" ]
