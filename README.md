# Secure Ingress via Azure Loadbalancer and Palo Alto Firewall

## Introductions
This repo contains the terraform code for provisioning the resources described in the architecture diagram.

*Assumptions:* Some familiarity with Palo Alto firewall and Azure. Palo Alto requires some initial configuration, some knowledge or at least entusiasim to learn is required as there is bound to be some troubleshooting and manual configuration needed after or during deplopyment. 

## Where to find the blog post

The blog post cab be found here [xxx](https://xxx)

## Building out the Infrastructure

Checkout the repo, in the root directory of the project, open a new terminal and log into your Azure account like so

```bash
az login
```

_The assumption is that you have an Azure account with the relevant permissions and role to create resources. To findout more about roles see this [Azure documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)_

<details>
<summary> Step 1 - Planing </summary>

As with any network you have to plan before you begin. You need to answer questions like:

- What network address spaces can i use, overlaps will cause issues.
- Do i have enough IP addresses?.
- How large does want my virtual networks (vNet) to be to support the devices that would be provisioned and leave space for growth.

In this instance we'll use 3 `/24` vNets

- Hub: `10.0.1.0/24`
- Spoke 1: `10.0.2.0/24`
- Spoke 2: `10.0.3.0/24`

A website i find useful in dividing up IPs is the (Visual Subnet Calculator)[https://www.davidc.net/sites/default/subnets/subnets.html]

Other things to think about early include

- Naming conventions, use names that help identify resource easily. This is different for various organisation and there are standards that you can leverage
  - See the [Terraform Best Practices](https://www.terraform-best-practices.com/naming) docs for naming convention for IaC code
  - See the [Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) docs for naming convention for cloud resources
- How to make your project reusable. This is where having a `.tfvars` file shines. Avoid where possible hard coded values
 in the code itself
</details>

### Resource Groups

In Azure most things you provision need to have or belong to a resource group. This will come in handy for us as we can quickly `create` and `destroy` the resource group to avoid any additional cost when taking this for a spin.

### The Creation

To get started, in your terminal, verify you are in the project root directory run:

```bash
terraform init
```

This will initialise the project and set terraform up.

Then run:

```bash
terraform plan -var="subscription_id=your-subscription-id" -var-file=dev.tfvars
```

Always best to review your terraform plan before you `apply` the changes. Look out for warning, errors, deprecation information etc.
 The reason for referencing the `tfvars` file is so terraform can automatically fill out the variables defined. In a CI workflow this file will be different based on which environment pipeline is running.

When satisfied with the `plan` output and there are no errors, run:

```bash
terraform apply -var="subscription_id=your-subscription-id" -var-file=dev.tfvars
```

_Note: How do you [auto approve](https://developer.hashicorp.com/terraform/cli/commands/apply) your terraform `apply`? Can you figure that out?_



### Azure Bastion

Access to backend services is a needed capability in any network. Mostly because these services are and should not be public facing. There needs to be a way to still reach them without exposure and risks.

[Azure bastion](https://azure.microsoft.com/en-ca/products/azure-bastion) is a way to go. It does come at a cost though as is a manages service and Azure Bastion is generally more
cost-effective and secure than manually deploying and maintaining your own jumpbox, particularly when considering the total cost of ownership (TCO), including management time and potential security risks.
There is this good tutorial, [How to deploy Azure Bastion via Terraform](https://dev.to/holger/test-azure-bastion-deployment-via-terraform-18o8), check it out for more detail.

In our setup we deploy the bastion service in the management subnet on the hub, which has connectivity to the spokes

<details>
<summary> Step 2 - Setup </summary>

After all resources are deployed in Azure and the status of the Palo Alto firewall VM is `Ready` you could either

- 🏋🏽‍♀️ `(A)` Challenge yourself further and configure the Palo Alto firewall. This could be useful if [learning to administer](https://www.youtube.com/watch?v=7Q-fS7uZDhQ) a Palo Alto Next Generation Firewall NGFW.<br/>You would need to:

  - Login to the `cli` and create a new user account. Preferable an admin user with `superuser` role. Login via the Azure bastion from the portal. Remember you'll be using the username in the config and selecting the `ssh` key from the key vault. See [how to create users from pan-os cli](https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000ClFrCAK)
  - Add your public IP on the `nsg_management` so you can access the Palo Alto management UI
  - Configure the following
    
    - Zones
    - Interfaces, select `DHCP Client`
    - Virtual routes for outbound
    - NAT and Security policies to allow health probes

    Follow Palo Alto official documentation to get going. Some useful resource include
    
    - [Palo Alto Firewall Configuration Step by Step](https://www.youtube.com/watch?v=_en8gPflPec)
    - [Perform Initial Configuration](https://docs.paloaltonetworks.com/pan-os/11-0/pan-os-admin/getting-started/integrate-the-firewall-into-your-management-network/perform-initial-configuration)
    - [Next-Generation Firewall](xxx)
   

- 🚶🏾‍♂️`(B)` Login to the `cli` via the Azure bastion, see [how to create users from pan-os cli](https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000ClFrCAK), and create a new user account.<br> Use the follow values:<br> `Username:admin` and
  `Password:adminUser12345`.
  - Add your public IP on the `nsg_management` so you can access the Palo Alto management UI
  - In the repo there should be a `running-configuration-blog.xml` file. [Upload](https://www.youtube.com/watch?v=JXumelUwAoY) the file and `commit` it.
  - Verify the following after a few minutes
    - The network interface are now active, keep a note of the private IPs  and gateway IP addresses assigned.
    - Internal loadbalancer now healthy.
  - Update the Palo Alto [virtual router](https://www.youtube.com/watch?v=oMtvXCipFCc) with the correct gateway IPs assigned to the firewall interfaces.
  - Log into the spoke vms via the bastion using user credentials from the `tfvars` file and save the ssh keys and password from key vault
    - On the Ubuntu vm [install](https://www.youtube.com/playlist?list=PL4dMEnNM6g1OY1kStFqnF4CJJeqy4exS3) Apache
    - On the Windows vm [install](https://www.youtube.com/watch?v=0svvyhYFbOw) IIS
  - In the NAT policies and security polices, use the current public IPs on your vms, the policies have a `webserver-*` naming format
    - Verify the public loadbalancer is now showing healthy
  - Test east-west by `curl`ing one private ip from the other vm e.g. from `10.0.3.4` call `10.0.2.4` if you used the same `tfvars` values as in the example
  - Test outbound, e.g. `curl` `www.google.com` or some other public endpoint. If on the Windows server you can open the web browser in the RDP session window and navigate to public domains.

You could check out this [YouTube](https://www.youtube.com/watch?v=HVZ8-PwLJSc) video for some context on configuring Palo Alto firewalls
</details>

### What's next?

Palo Alto firewalls are powerful devices with a lot of capabilities. Some next steps you could take include
- exploring more advanced features like URL filtering, threat prevention, and application control to enhance your network security.
- Integrating with full CI/CD pipelines for automated deployments. Have a look at this [DevOps the hard way in Azure](https://thomasthornton.cloud/2021/10/25/devops-the-hard-way-in-azure/) blog post for some ideas
- Implementing high availability (HA) for the Palo Alto firewall to ensure continuous network protection.
- Adding monitoring and logging solutions to keep an eye on network traffic and security events.

<details>
<summary> Step 3 - Troubleshoot </summary>

The plan may fail for various reasons permissions, policies on the subscription etc. Hopefully you can make sense of what terraform or Azure is complaining about by searching the internet or using tools like Copilot.
<br><br>
Commons ones include:

- VM SKU types, you might need to adjust the `tfvars` file.
- Resource limitations on your Azure account, especially if a personal one.
- Existing policies on the Azure account like tagging requirements.
- Different IP or Gateway addresses assigned by Azure than what is in the provided config for the Palo Alto firewall.

Errors though should be fairly resolvable and nothing too complicated to fix, this is where your troubleshooting skills come in handy and also what you most likely face in real world scenarios.

</details>

### ⚠️ Dont Forget?

The resources created in this demo will incur costs on your Azure account. To avoid unexpected charges, remember to destroy the resources once you are done experimenting.

If taking a break inbetween you can do some of the following to reduce cost:

- Stop the Palo Alto firewall VM when not in use. Note that stopping the VM from the portal will still incur costs for the allocated resources like public IPs, disks etc.
- Stop all the VMs in the spokes when not in use.
- Comment out the bastion resource in the terraform code when not in use and run `terraform apply` again to remove it from Azure. You can always uncomment it later and run `terraform apply` to add it back.

When ready to destroy all resources run or done with the demo run:

```bash
terraform destroy -var="subscription_id=your-subscription-id" -var-file=dev.tfvars
```

Wait for the process to complete and verify in the Azure portal that all resources have been removed.
