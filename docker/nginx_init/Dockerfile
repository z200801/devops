FROM nginx:latest

COPY init/entrypoint.sh /entrypoint.sh
COPY html/index.html /usr/share/nginx/html/index.html

EXPOSE 80

ENTRYPOINT ["/bin/sh","/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
