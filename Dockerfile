FROM docker.io/debian:stable-slim

RUN apt update && apt -y install curl jq cron && apt clean
RUN mkdir /opt/PorkbunDDNS-Shell
COPY lib /opt/PorkbunDDNS-Shell/lib
COPY plugins /opt/PorkbunDDNS-Shell/plugins
COPY PorkbunDDNS.sh /opt/PorkbunDDNS-Shell/
RUN echo "* * * * * /opt/PorkbunDDNS-Shell/PorkbunDDNS.sh" >>/etc/cron.d/crontab
RUN /usr/bin/crontab /etc/cron.d/crontab

ENV CONTAINER_RUNNING "1"
ENV ip_api_url "https://api64.ipify.org?format=text"
ENV access_key_id "your-access-key-id"
ENV access_key_secret "your-access-key-secret"
ENV domain_name "domain.com"
ENV host_record "@"
ENV use_ipv4 "1"
ENV use_ipv6 "1"
ENV p_sample_enable "0"
ENV p_sample_var "it's a sample"
ENV p_work_weixin_enable "0"
ENV p_work_weixin_corpid "your-corpid"
ENV p_work_weixin_corpsecret "your-corpsecret"
ENV p_work_weixin_agentid "your-agentid"
ENV p_work_weixin_post_type 'textcard'
ENV p_work_weixin_content "new ip is \$new_ip"
ENV p_work_weixin_title "Aliyun DDNS Message"
ENV p_work_weixin_url "https://google.com"
ENV p_telegram_enable "0"
ENV p_telegram_botid ""
ENV p_telegram_chatid ""
ENV p_telegram_content_update "\$host_record.\$domain_name ip has updated, \$old_ip -> \$new_ip"
ENV p_telegram_content_create "\$host_record.\$domain_name ip has created, ip is \$new_ip"

CMD ["cron", "-f"]
