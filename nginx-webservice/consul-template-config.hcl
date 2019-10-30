# consul-template-config.hcl
# configuration consul-template to use local instance of consul agent
# file should be located in /consul-template.d/ dir
consul {
address = "localhost:8500"
retry {
enabled = true
attempts = 12
backoff = "250ms"

}
template {
source      = "/etc/nginx/conf.d/load-balancer.conf.ctmpl"
destination = "/etc/nginx/conf.d/load-balancer.conf"
perms = 0600
command = "systemctl service nginx reload"
}