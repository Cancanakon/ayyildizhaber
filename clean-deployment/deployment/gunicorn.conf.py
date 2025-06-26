# Gunicorn configuration file for production
import os

# Server socket
bind = "0.0.0.0:5000"
backlog = 2048

# Worker processes
workers = 4
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2

# Restart workers after this many requests, to help prevent memory leaks
max_requests = 1000
max_requests_jitter = 100

# Logging
accesslog = "/var/log/ayyildizhaber/access.log"
errorlog = "/var/log/ayyildizhaber/error.log"
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'

# Process naming
proc_name = "ayyildizhaber"

# Daemon mode
daemon = False
pidfile = "/var/run/ayyildizhaber/gunicorn.pid"

# User and group to run as
user = "www-data"
group = "www-data"

# Server mechanics
preload_app = True
sendfile = True
reuse_port = True

# SSL (uncomment when you have SSL certificates)
# keyfile = "/etc/ssl/private/ayyildizhaber.key"
# certfile = "/etc/ssl/certs/ayyildizhaber.crt"