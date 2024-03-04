# Use the latest Ubuntu image
FROM ubuntu:latest

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Update repositories
RUN apt-get update

# Install SSH server, rsyslog, and other necessary tools
RUN apt-get install -y openssh-server rsyslog iputils-ping sudo nano wget curl

# Install supervisor
RUN apt-get install -y supervisor

# Configure SSH
RUN mkdir /var/run/sshd
RUN echo 'root:password' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Create supervisord configuration file
RUN echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf
RUN echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "user=root" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "[program:sshd]" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "command=/usr/sbin/sshd -D" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "[program:rsyslog]" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "command=/usr/sbin/rsyslogd -n" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord.conf

# Environment variable for SSH
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# Expose SSH port
EXPOSE 22

# Run supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
