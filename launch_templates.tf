# ==================================================
# WEB TIER LAUNCH TEMPLATE
# ==================================================

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.web_instance_type

  # Session Manager access
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  # Only the external ALB can reach the web tier.
  vpc_security_group_ids = [
    aws_security_group.web_tier.id
  ]

  # Require IMDSv2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # --------------------------------------------------
  # WEB TIER USER DATA
  # --------------------------------------------------

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    APP_DIR="/opt/three-tier-web-application-flask"

    # Install operating-system packages
    dnf update -y
    dnf install -y git nginx python3 python3-pip

    # Clone the original workshop repository
    git clone --depth 1 \
      https://github.com/aws-samples/three-tier-web-application-flask.git \
      "$APP_DIR"

    # Create an isolated Python environment
    python3 -m venv "$APP_DIR/venv"

    "$APP_DIR/venv/bin/python" -m pip install --upgrade pip

    # Install the actual WebLayer requirements
    "$APP_DIR/venv/bin/pip" install \
      -r "$APP_DIR/WebLayer/requirements.txt"

    # Allow the application service user to access the code
    chown -R ec2-user:ec2-user "$APP_DIR"

    # ------------------------------------------------
    # SYSTEMD SERVICE FOR THE WEB APPLICATION
    # ------------------------------------------------

    cat >/etc/systemd/system/web-layer.service <<'SERVICE'
    [Unit]
    Description=Flask Web Layer via Gunicorn
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/three-tier-web-application-flask/WebLayer
    Environment=PYTHONUNBUFFERED=1
    ExecStart=/opt/three-tier-web-application-flask/venv/bin/gunicorn --workers 2 --bind 127.0.0.1:8000 app:app
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    SERVICE

    # ------------------------------------------------
    # NGINX REVERSE PROXY
    # ------------------------------------------------

    cat >/etc/nginx/conf.d/default.conf <<'NGINX'
    server {
        listen 80;
        server_name _;

        location = /api {
            return 301 /api/;
        }

        # Send API requests to the internal ALB.
        location /api/ {
            proxy_pass http://${aws_lb.internal.dns_name}/;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Send normal web requests to local Gunicorn.
        location / {
            proxy_pass http://127.0.0.1:8000;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    NGINX

    # Validate Nginx configuration
    nginx -t

    # Enable both services at boot and start them now
    systemctl daemon-reload
    systemctl enable --now web-layer
    systemctl enable nginx
    systemctl restart nginx
  EOF
  )

  # Tag the EBS volumes created from this template
  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.project_name}-web-volume"
      Project = var.project_name
      Tier    = "web"
    }
  }
}


# ==================================================
# APP TIER LAUNCH TEMPLATE
# ==================================================

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.app_instance_type

  # Session Manager + app-specific Parameter Store access
  iam_instance_profile {
    name = aws_iam_instance_profile.app_tier.name
  }

  # Only the internal ALB can reach the app tier on 4000.
  vpc_security_group_ids = [
    aws_security_group.app_tier.id
  ]

  # Require IMDSv2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # --------------------------------------------------
  # APP TIER USER DATA
  # --------------------------------------------------

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    APP_DIR="/opt/three-tier-web-application-flask"

    # Install operating-system packages
    dnf update -y
    dnf install -y git python3 python3-pip

    # Clone the original workshop repository
    git clone --depth 1 \
      https://github.com/aws-samples/three-tier-web-application-flask.git \
      "$APP_DIR"

    # Create an isolated Python environment
    python3 -m venv "$APP_DIR/venv"

    "$APP_DIR/venv/bin/python" -m pip install --upgrade pip

    # Install the actual ApplicationLayer requirements
    "$APP_DIR/venv/bin/pip" install \
      -r "$APP_DIR/ApplicationLayer/requirements.txt"

    # Gunicorn is not included in the current app-tier
    # requirements file, so install it separately.
    "$APP_DIR/venv/bin/pip" install gunicorn

    # Allow the application service user to access the code
    chown -R ec2-user:ec2-user "$APP_DIR"

    # ------------------------------------------------
    # SYSTEMD SERVICE FOR THE APPLICATION
    # ------------------------------------------------

    cat >/etc/systemd/system/app-layer.service <<'SERVICE'
    [Unit]
    Description=Flask Application Layer via Gunicorn
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/three-tier-web-application-flask/ApplicationLayer
    Environment="AWS_DEFAULT_REGION=${var.region}"
    Environment=PYTHONUNBUFFERED=1
    ExecStart=/opt/three-tier-web-application-flask/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:4000 app:app
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    SERVICE

    # Register, enable and start the service
    systemctl daemon-reload
    systemctl enable --now app-layer
  EOF
  )

  # Tag the EBS volumes created from this template
  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.project_name}-app-volume"
      Project = var.project_name
      Tier    = "app"
    }
  }
}