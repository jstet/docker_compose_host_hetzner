# docker_compose_host_hetzner
This is a Copier IaC template to deploy a docker compose app on a Hetzner VPS.

## Dependecies
- [Copier](https://copier.readthedocs.io/en/latest/)
- Terraform
- Ansible
- Ansible Role UBUNTU22-CIS: 

    ```
    ansible-galaxy install -r ansible/requirements.yml
    ```

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
