## Demo Apps and Tutorials

- .NET Hello World Microservice [link](https://dotnet.microsoft.com/learn/aspnet/microservice-tutorial/create)

- ASP.NET in Azure with SQL DB: [link](https://docs.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-dotnet-sqldatabase)

- w3schools ASP.NET view DB: [link](https://www.w3schools.com/asp/webpages_database.asp)

## Create Consul binary path

- download and extract executable:

https://releases.hashicorp.com/consul/1.6.1/consul_1.6.1_windows_amd64.zip

- unzip to c:/consul

## Create Consul configuration file



## Create Consul service using SC Utility

[learn.hashicorp guide](https://learn.hashicorp.com/consul/datacenter-deploy/windows)

`sc.exe create "Consul" binPath= "<path to the Consul.exe> agent-config-dir <path to configuration directory>" start= auto`

## Start Consul service

- use SC utility:

`sc start "Consul"`

- use Service applet via GUI:

Windows Service Manager > Consul Service : Start