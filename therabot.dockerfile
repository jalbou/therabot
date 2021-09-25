FROM ubuntu:latest
# Install cron & other utilities
RUN apt-get update
RUN apt-get -y install cron wget apt-transport-https software-properties-common

# Install Powershell Core
RUN wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN apt-get update
RUN add-apt-repository universe
RUN apt-get install -y powershell
RUN pwsh -c "Install-Module PowerHTML -force"
#Create Therabot HOMEDIR
RUN mkdir /home/therabot

# Add crontab file in the cron directory
ADD https://raw.githubusercontent.com/jalbou/therabot/main/crontab /etc/cron.d/simple-cron

# Add Powershell script
ADD https://raw.githubusercontent.com/jalbou/therabot/main/therabot.ps1 /home/therabot/therabot.ps1

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/simple-cron

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Run the command on container startup
CMD cron && tail -f /var/log/cron.log
