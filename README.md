## WireGuard + Web UI via Terraform on GCP

spin up a vpn in your country as you are travelling

    git clone wgeasy-terra
    cd wgeasy-terra
    terraform init
    terraform apply

enjoy


You need to configure GCP
add a Bucket for the state file

Delete everything

    cd wgeasy-terra
    terraform destroy

It is running in a docker container
traefik is providing an ssl cert via letsencrypt

## vm will restart after creation 
It runs some systemd service for one time to start the creation of the containers


##terraform.tfvars
    ssh_pubkey = ""

    password_hash = ""

    acme_email = "your email"

pubkey you only need if not using OS Login

password hash

    htpasswd -nbB user Passwort | cut -d: -f2
