# docker_compose_host_hetzner
This is a Copier IaC template to deploy a docker compose app on a Hetzner VPS. I use it for personal projects. Use it at your own risk. Creating VPS on hetzner generates costs.

## Dependecies
- [Copier](https://copier.readthedocs.io/en/latest/)
- Terraform
- Ansible
- Ansible Role UBUNTU22-CIS: 

    ```
    ansible-galaxy install -r ansible/requirements.yml
    ```

## Generate project
```
copier copy gh:jstet/docker_compose_host_hetzner  <project_name>
```
This will start an interactive prompt.
!! If you dont want sensitive credentials included in your code, answer no to the question regarding creation of setup.sh. !! Setup.sh is added to .gitignore 


## Steps after Generation

1. Set environment variables
To use the hetzner apis with terraform you need an [API token](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/) for the cloud service and an API token for the [DNS console](https://docs.hetzner.com/de/dns-console/dns/general/api-access-token/). Best practice is to set these tokens via the terminal with `export HCLOUD_TOKEN="token"` so they are not included in your code. As I am too lazy however and I am the only one at risk in personal projects I usually use a bash script to do this automatically. This is what the last two questions during project generation are for. If you have answered them, run this code while in root folder:
    ```
    source setup.sh
    ```

2. Initialize terraform
    ```
    cd terraform
    terraform init
    ```
3. If you dont want to change the terraform script, run the teraform apply command. The also generates a plan that you can review before approving it. After approval the VPS will be created.
    ```
    terraform apply
    ```
4. Add deployment code to ansible/playbook.yml. For example add a docker compose template and copy it to server. Wait some time before running the ansible playbook, because the cloud init script needs to finish first

## Configurable Vars
- Name of server
- Server Type
- Image
- Location
- Backups
- docker compose version
- ssh key path
- dns zone name
- subdomain 
