server {
    listen ${LISTEN_PORT};

    location /static {
    location /static/static {
        alias /vol/static/static;
    }
    location /static/media {
        alias /vol/media;

    }
    }

    location / {
        include              gunicorn_headers;
        proxy_redirect       off;
        proxy_pass           http://${APP_HOST}:${APP_PORT};
        client_max_body_size 10M;
    }
}
