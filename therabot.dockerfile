FROM ubuntu:latest
# Install utilities
RUN apt-get update
RUN apt-get -y install wget apt-transport-https software-properties-common

# Install Powershell Core & PowerHTML Module
RUN wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN apt-get update
RUN add-apt-repository universe
RUN apt-get install -y powershell
RUN pwsh -c "Install-Module PowerHTML -force"
#Create Therabot HOMEDIR
RUN mkdir /home/therabot

# Add Powershell script
ADD https://raw.githubusercontent.com/jalbou/therabot/main/therabot.ps1 /home/therabot/therabot.ps1

# Run the command on container startup
CMD pwsh /home/therabot/therabot.ps1
