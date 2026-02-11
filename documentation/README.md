# posit-team-pre-reqs

**Author**: Lisa Anders heavily inspired by resources and conversations in the Solutions Engineering team, especially SamC, Katie, MichaelM, Monanshi, and the West Study Group

**Target audience**: An admin attempting to do an install. The below should be a good judge of capability while still providing guidance on preparing the infrastructure. 

# Preparing for your Posit Team Install

Your Posit Team install is a big step on the road to enterprise data science. Congratulations! There are a couple things you can prepare early so that your install will go smoothly. 

This guide is meant for someone that already has linux experience. Our products run on linux and while we do our best they are complex products requiring knowledge and curiosity to run successfully. These steps below should be possible to complete independently by a competent administrator and are a good gauge of readiness for maintaining the Posit Team suite of products. If this looks like too much please reach out to our sales team to discuss other options like managed services, Posit cloud, or running the editors locally. There are options. 

## Server selection 

Plan on having both a production and a staging environment (at the minimum) to follow our best practices. This will enable testing of upgrades, patching, etc in the staging environment prior to rolling it out to production. Whenever any changes happen on a server there is risk of down time. By having an identical version of your production environment where those issues can be encountered and resolution can have as long as it needs then when the production upgrade happens you'll know the steps for a fast and painless upgrade process. 

Make sure that the configuration and sizing is large enough to support your use cases (or is able to be expanded in the future). We have some starting recommmendations [in the Configuration and sizing recommendations support article](https://support.posit.co/hc/en-us/articles/115002344588-Configuration-and-sizing-recommendations). 

Make sure that the OS selected is a [supported version](https://docs.posit.co/platform-support.html). It should be a flavor of linux and one that your IT team is knowledgable in supporting. 

Note that we do not recommend running multiple of the products on the same server. Our best practice recommendation is to run each product on its own dedicated hardware. While it may seem appealing there are a couple reasons why this generally is a bad idea. There is a [support article here](https://support.posit.co/hc/en-us/articles/4419660407063-Running-Multiple-RStudio-Products-on-the-same-Machine) that goes into this in more detail. 

## Pre-requisites

### Who is needed for the install

In order to do the install a linux administrator with root access will be needed. While not always necessary, running commands with `sudo` privileges is the happy path to guarantee success and is a much easier install if that level of access is allowed. 

At times through the install other administrators may also be needed, notably for storage, databases, and/or authentication. Networking, security, or admins for specific cloud platforms may also be needed. Make sure you've lined up people that can be reached out to that will be available to help as needed. 

Last but not least make sure that you have a strong representative(s) for your various data science communities. The Posit products  are very configurable and there are many choices that will easier to navigate if you have a stakeholder who will use the product involved in making the decision. 

### Preparing the servers 

Make sure that any server patching, upgrades, connections to a vendor support, or repositories have been set up. 

For RHEL based systems follow the instructions here: [Install required dependencies](https://docs.posit.co/resources/install-r.html#install-required-dependencies) 

Example checking if RHEL subscriptions have been set up: 

```bash
# (RHEL only) Check that subscription manager is connected and RHEL license is enabled 
sudo subscription-manager repos --list 
```

Be sure to restart the software if needed to pull in any updates: 

```bash
# Can also use reboot, in RHEL systems these are functionally the same
sudo shutdown -r now
```

### Server hardening

Disabling any server hardening, or being able to promptly review and enable the alerts, will be needed for specific commands. The easiest option is to disable any server hardening temporarily during the install and then enable it afterwords. The challenge with server hardening is that the error messages are usually borderline nonexistent if existent at all and it's very difficult to tell if the issue is server hardening or a missed step in the install process. 

Selinux has three modes: enforcing, permissive, disabled. Permissive mode makes it so that any potential issues are flagged and logged, but won't be blocked. This is a command that will set selinux to permissive mode: 

> Is this really the command for permissive mode? 

```bash
# Set selinux to permissive
sudo setenforce 0

# Set selinux to permissive, persists after a restart
sudo setenforce 0 && sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# Check selinux mode 
sestatus
```

Workbench has a selinux module that can be used after install to run with selinux set to `enforcing`. Install this module prior to installing the software, following [the instructions here](https://docs.posit.co/ide/server-pro/admin/access_and_security/selinux_configuration.html). 

Another common issue related to server hardening is an overly restrictive umask during installation. For example, if umask is set to `0077`, packages added to `site-packages` during the Python installation are inaccessible within user sessions, and Jupyter sessions will fail to launch. 

```bash
# Check the umask level 
umask 

# Set umask to a more permissive level 
umask 020
```

If cgroups is enabled (for example, typically on by default with Rhel9) then make sure that the Workbench cgroups integration is configured. 

### Networking 

> How do we check that networking  looks good? 

For multi node deployments make sure that all nodes can access each toher:


Networking ports can also be a common challenge if certain ports are blocked. Review the [cheatsheet of Networking](https://docs.posit.co/getting-started/networking.html) to make sure all needed ports have been opened. Note that these ports are needed internally inside your network, outbound is not required (but can make things a lot easier). The recommendation for very closed off installations would be to open up the firewall temporarily so that files can be downloaded for install more easily instead of needing to download on a separate device and then upload them. 

```bash
# Verify the correct IP address comes back for each server 
nslookup

# Check if firewalld is enabled
sudo firewall-cmd --state

# (Optional) Disable firewalld
systemctl stop firewalld && systemctl disable firewalld # RHEL
ufw disable # Ubuntu

# If you find that "privileged ports", like 443, are being blocked from being listened on use this command to grant the relevant service (package mmanager in this example) binary permission to do so
sudo setcap 'cap_net_bind_service=+ep' /opt/rstudio-pm/bin/rstudio-pm
```



### Storage 

Additional storage is not necessarily needed. If the architecture desired is a single server and doesn't need failover or redundancy then using the on disk storage might be sufficient. That is the fastest option, and doesn't require any additional configuration or setup. 

The software will need write privileges to /tmp, `noexec` will cause issues during the install process. This can be otionally set if needed for the relevant software user account with `chown rstudio-pm: /tmp` or `chmod 1777 /tmp`. Alternatively a new tmp location can be created that will allow write privileges. You can confirm the privileges via the command  `namei -l /tmp`​.

In the case of robust, high availability/load balanced, containerized, kubernetes, or slurm deployments then a mounted shared drive for all nodes for a product in a particular environment (staging or production) will be needed. Review the [storage options article](https://docs.posit.co/getting-started/storage.html) to determine what will work for you. Typically with storage you get what you pay for, so the cheapest options, while tempting, often run into issues with latency and performance. The storage recommendation simplistically boils down to recommending something NFS based (with the note that S3 can work for Package Manager as well). 

The rest of this section will focus on tips for mounting NFS storage. 

Be sure to consult the [Deploying NFS for high availability deployments support article](https://support.posit.co/hc/en-us/articles/360060548093-Deploying-NFS-for-High-Availability-Deployments)  and the [How to mount shared storage steps from the Workbench Admin guide](https://docs.posit.co/ide/server-pro/admin/getting_started/installation/multi_server_installation.html#mount-shared-storage ) for some help to get things set up. 

On the prepared servers the needed system dependencies will need to be install, likely `nfs-utils`. 

It's a good idea to go through the process of manually mounting, making sure everything works, unmounting it, and then adding it to fstab so it will persist in the case of server restarts. 

```bash
# List of filesystems exported from nfs server where hostname is the hostname of the nfs server 
showmount <hostname>

# Mount the share drive (interactive mode, this won't persist if the server is rebooted)
mount hostname:/data/home /home

# See mounted shares
showmount 
mount -a
mount

# Unmount prior to adding to fstab
umount /mountDir
```

Example entry in `/etc/fstab`: 

```bash
hostname:/data/Connect /home nfs default
```

After modifying `/etc/fstab` pull it in with: `sudo systemctl daemon-reload`

>  what is this about? One more thing fstab nfsif want to make sure is mountd on boot there is a command you'll want to add something like _netdev to the fstab, here is the command: `defaults,_netdev` 

In the case of permissions issues a useful command to know that will update the permissions of affected files and directories using `chmod -R og+rX`. This allows all users and groups to read the files, search inside the directories, and run any programs that already have the execute permission set.

> Another issue that pops up is we need /tmp needs to be executable, which isnt always the case. Should say something about how to create a new directory and use that instead in the case that /tmp doesn't allow execution. 

> Pull in more from here: <https://docs.posit.co/ide/server-pro/admin/getting_started/installation/multi_server_installation.html#mount-shared-storage> 

### Database

An additional database is not necessarily needed. If the architecture desired is a single server and doesn't need failover or redundancy then using the built-in sqlite database might be sufficient. That is the fastest option, and doesn't require any additional configuration or setup. 

In the case of robust, high availability/load balanced, containerized, kubernetes, or slurm deployments then an external postgres database is required for all nodes for a product in a particular environment (staging or production). 

The rest of this section will focus on tips for setting up a Postgres database. 

Work with your database team to create and configure your postgres database. One postgres server can be used for multiple products, however each product environment will need its own database within that postgres server with its own username and password. 

Here's an example of how to create a database and user remotely, without creating a postgres session: 

```bash
# Create database role (user) and Database for Connect, duplicate this for the other products (be sure to update the names)
sudo -i -u postgres psql -c "CREATE ROLE positConnectAdmin CREATEDB LOGIN PASSWORD 'test';"
sudo -i -u postgres psql -c "CREATE DATABASE positConnect WITH OWNER = positConnectAdmin;"
```

Here's an example of testing network access to the postgres database from the server the software will be hosted on: 

```bash
# Test database connection
psql -h instance-eks-rds.cpbvczwgws3n.us-east-2.rds.amazonaws.com -U posit_connect -d posit_connect -c '\conninfo'
```

Be sure to capture the details of the connection string, username, and password for use later. The connection string will be in a format like `postgres://username@db.seed.co/posit` with any optional connection details at the end, like `?options=-csearch_path=connect_schema`. 

### Load balancers / Proxy / Ingress

Prepare whichever ingress is needed if it is being used. The ingress will need an SSL certificate in order to be accessed over https and we recommend having sticky sessions enabled. Each product and environment will need its own ingress. 

Each admin guide has an additional section discussing considerations when running with a proxy. If that applies to your desired setup, it is highly recommend you seek out and read those pages. 

### License files 

By now you should have received a license file or key from Posit. If using a license file be sure to copy it to the environment where it is needed. Each license is specific to that product. So while the same license will be shared across your production and staging environments, they will be different for each software product. 

### SSL certificates 

[Verify TLS certificates and keys](https://docs.posit.co/how-to-guides/guides/install-ssl-certificates.html) (without passphrases) including the full certificate chain up to and including the root CA certificate. The certificate and key should be copied to the server ready to be copied into its relevant folder after the software has been installed following the install instructions. Wildcard certs are a great option if you want to cover multiple servers under a single domain. 

In the case of installs using ingress there is a choice: 

- Most customers will choose to have ssl certs at the ingress controller / load balancer layer and terminate at that layer. Within the cluster communication is not encrypted, over http. This can be an acceptable risk for many organizations. 
- For security concerned customers they will havve the same with the SSL certs at the ingress controller / load balancer layer but additionally will have certs installed on each node so that all traffic is over https. 

In the case of a kubernetes installation we strongly recommend considering using a service mesh. A service mesh can be used for many things, one of those being creating a blanket of TLS across the cluster. In a kubernetes environment the challenge is that resources are transient. Since SSL certs are typically allocated to a specific address (even with the ability to do wildcards) it can be very challenging to get things working since you may not have persistent host names. A service mesh solves this problem. 

### Install R 

Install R following [our instructions here](https://docs.posit.co/resources/install-r.html) on: 

- Workbench server where R users will be running sessions 
- Connect server where R users will be deploying content 
- Package Manager server where internally developed R packages will be built and served 

Check with your data science community to confirm those use cases, of if it should be skipped on any systems. 

Check with your developers if a specific version is needed, otherwise the recommendation is to go with the latest production release. Multiple versions can be installed to run side by side to support projects developed at different times. 

Find all installed R versions with: `ls -ld /opt/R/*`

### Install Python

Install Python following [our instructions here](https://docs.posit.co/resources/install-python-uv.html) on: 

- Workbench server where Python users will be running sessions 
- Connect server where Python users will be deploying content 
- Package Manager server where internally developed Python packages will be built and served 

Check with your data science community to confirm those use cases, of if it should be skipped on any systems. 

Check with your developers if a specific version is needed, otherwise the recommendation is to go with the latest production release. Multiple versions can be installed to run side by side to support projects developed at different times. 

Find all installed python versions with: `ls -1d /opt/python/*`

### Install Quarto

Installation of Quarto is only needed on Connect. Install quarto following [our instructions here](https://docs.posit.co/resources/install-quarto.html). Check with your developers if a specific version is needed, otherwise the recommendation is to go with the latest production release. Multiple versions can be installed to run side by side to support projects developed at different times. 

Find all installed quarto versions with: `ls -ld /opt/quarto*` and `quarto check`

### Prepare for user data access

Users will likely need data source access for their day to day workflows whether working on Workbench and developing resources, or deploying content to Connect that will update the visualizations as the underlying data updates. 

Depending on the resources your organization has, and the analytics being built, some of the data connections that might make sense to integrate with include databases, pinned data sets, flat files like csv’s stored in the project directory or a shared directory, mounted network drives, pins, blob storage like Azure torge or s3 buckets, or some other kind of interface.

Data source connections are hndled by the R or Python code written by the developer, not by Workbench or Connect. Connection feasibility is determined solely by the underlying Linux server environment. If a connection can be established from a standalone R or Python session on that server, the same connection will be available when running the code via Workbench or Connect.

Compile a list of all needed data sources and the methods for connecting to them. For the different types of data sources different pre-reqs may be needed: 

- Mounted shares : Make sure any shares are mounted to the shares and the path is documented for developers to use
- Databases : [Install the pro drivers](https://docs.posit.co/pro-drivers/server/) or any other needed drivers and (optionally) create the /etc/odbcinst.ini to make access easier so that developers can use a name to connect to a database instead of need to know full address and ports
- Blob storage : Document the locations and connection methods for the blob storage. Access is typically through a package (like paws or aws.s3). 
- Others : Taken on a case by case basis, document the current methods for access and make sure any pre-requisites are installed on the servers

Posit has support for oauth integrations to data sources. This makes it so that instead of needing to provisionion service accounts or secrets that developers then need to guard, they can instead get a "pass through" experience where after logging in a short-term token is cache'd that can be used to enable password-less data access. In order to enable this an additional oauth application will need to be created to enable that access on a per data source level. Review the 

- Posit Workbench and Managed Credentials: <https://docs.posit.co/ide/server-pro/user/posit-workbench/managed-credentials/managed-credentials.html>
- Posit Connect and Oauth Integrations: <https://docs.posit.co/connect/user/oauth-integrations/>

### Email server

Have the details for you email server handy for Connect for sending emails as a SMTP connection. 

### Authentication and authorization

For any authentication systems that are desired to be integrated with, configuration will be needed from the perspective of the authentication provider. Typically they will need to configure users and groups that should have access, SSO and MFA requirements, and will use the information from your server address, DSN, or ingress to know the appropriate redirect URL. In the case of user provisioning via a system like SCIM then additional set up and details are likely needed. Work closely with your auth team in order to create these in advance of the install. 

There are multiple authentication modes that are supported that can be chosen from. Both SAML and OpenID/Oauth support SSO and are recommended over other methods since it leverages the full capablity of using an enterprise authentication provider. Oauth is typically preferred as the stronger choice and the gold standard for secure authentication currently. This is due to its use of tokens. Importantly they are short-lived, usually expiring after an hour, so the risk of exposure and abuse is much lower than other options. However, if there is an existing Active Directory (AD) service or LDAP service and a knowledgeable IT team for those services than that can also work. 

> How to test that authentication will work? group command

### HPC installations 

> Anything to know or prep for slurm or k8s? 

Follow the pre-req and pre-flight install steps [here for kubernetes](https://docs.posit.co/ide/server-pro/admin/integration/launcher-kubernetes.html) 

Prepare any pre-reqs for container images for your kubernetes environment. 

Follow the pre-req and pre-flight install steps [here for slurm](https://docs.posit.co/ide/server-pro/admin/integration/launcher-slurm.html) 

If using slurm consider whether or not singulatiry/apptainer images are desired and prepare the requirements for those images as needed.  

Read this email and incorporate: Fwd: Posit <-> BofA: SLURM Call Summary and next steps

### Cheat sheet commands 

There are a couple commands that are useful to keep at your fingerprints while going through the install. 

#### Package Manager 

Add account to rstudio-pm group in order to use the cli: `sudo usermod -aG rstudio-pm ubuntu`

Without an alias call the CLI directly: ``/opt/rstudio-pm/bin/rspm --help`

Config lives at: `/etc/rstudio-pm/rstudio-pm.gcfg` 

```bash
# Start/ Stop / Restart commands
sudo systemctl stop rstudio-pm
sudo systemctl start rstudio-pm

# Status command
sudo systemctl status rstudio-pm
sudo systemctl status rstudio-pm 2>&1 | tee status.txt

# View logs 
sudo tail -n 50 /var/log/rstudio/rstudio-pm/rstudio-pm.log
sudo tail -n 50 /var/log/rstudio/rstudio-pm/rstudio-pm.log | grep error*
sudo journalctl -xe -u rstudio-pm
```

#### Connect

Config lives at: `/etc/rstudio-connect/rstudio-connect.gcfg` 

```bash
# Start/ Stop / Restart commands
sudo systemctl restart rstudio-connect
sudo systemctl stop rstudio-connect
sudo systemctl start rstudio-connect

# Status command
sudo systemctl status rstudio-connect
sudo systemctl status rstudio-connect 2>&1 | tee status.txt

# View logs 
sudo tail -n 50 /var/log/rstudio/rstudio-connect/rstudio-connect.log
sudo tail -n 50 /var/log/rstudio/rstudio-connect/rstudio-connect.log | grep error*
```

#### Workbench 

Add account to rstudio-server group: `sudo usermod -aG rstudio-server ubuntu`
For admin access add user to `rstudio-admin` group

Check if there are any active sessions running: ` sudo rstudio-server active-sessions`
If there are active sessions, then [suspend all](https://docs.posit.co/ide/server-pro/server_management/core_administrative_tasks.html#managing-active-sessions) active user sessions: `sudo rstudio-server suspend-all`

Configs live in: ` /etc/rstudio/` 

```bash
# Start/ Stop / Restart commands
sudo rstudio-server restart
sudo rstudio-server start
sudo rstudio-server stop
sudo rstudio-server start
sudo rstudio-launcher restart
sudo rstudio-launcher stop
sudo rstudio-launcher start

# Status command
sudo systemctl status rstudio-server
sudo systemctl status rstudio-server 2>&1 | tee status.txt
sudo systemctl status rstudio-launcher
sudo systemctl status rstudio-launcher 2>&1 | tee status.txt

# See nodes 
sudo rstudio-server list-nodes

# Some test CLI commands 
/opt/rstudio-pm/bin/rspm list
/opt/rstudio-pm/bin/rspm online

# View logs 
sudo tail -n 50 /var/log/rstudio/rstudio-server/rserver.log
sudo tail -n 50 /var/log/rstudio/launcher/rstudio-launcher.log | grep error*
```

## How long will the install process take? 

By following the above steps you are minimizing delays due to waiting for resources to become available. This process should now be fast and efficient, but its worth noting that depending on the complexity of your environment some installs will inherently take longer than others. 

At the end of the day, it's not about having to know everything. The most important quality in an admin is being able to be fearless and try things independently. As you go through the install our Support team is here to partner with you if you run into issues that we can help with. We our proud of the knowledge of our team, and hope you enjoy your interactions with them. 

We appreciate feedback! If there are steps we can better outline or document please let us know either by contacting your customer success representative with feedback, through submitting a support ticket, or letting us know in person at our annual conference. Thanks!


