FROM debian:jessie
MAINTAINER Le Filament <https://le-filament.com>

ENV APT_DEPS='python-dev build-essential libxml2-dev libxslt1-dev libjpeg-dev libfreetype6-dev \
              liblcms2-dev libopenjpeg-dev libtiff5-dev tk-dev tcl-dev linux-headers-amd64 \
              libpq-dev libldap2-dev libsasl2-dev' \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PGDATABASE=odoo

COPY ./requirements-lcc.txt /tmp/

RUN set -x; \
        sed -Ei 's@(^deb http://deb.debian.org/debian jessie-updates main$)@#\1@' /etc/apt/sources.list &&\
        apt-get update &&\
        apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
            fontconfig \
            git \
            libjpeg62-turbo \
            libtiff5 \ 
            libx11-6 \
            libxcb1 \
            libxext6 \
            libxml2 \
            libxrender1 \
            libxslt1.1 \
            node-less \
            python-gevent \
            python-ldap \
            python-qrcode \
            python-renderpm \
            python-support \
            python-vobject \
            python-watchdog \
            sudo \
            xfonts-75dpi \
            xfonts-base \
            && \
        echo 'deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main' >> /etc/apt/sources.list.d/postgresql.list &&\
        curl -SL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - &&\
        curl -o wkhtmltox.deb -SL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.jessie_amd64.deb &&\
        echo '4d104ff338dc2d2083457b3b1e9baab8ddf14202 wkhtmltox.deb' | sha1sum -c - &&\
        apt-get update &&\
        dpkg --install wkhtmltox.deb &&\
        apt-get install -y --no-install-recommends postgresql-client &&\
        apt-get install -y --no-install-recommends ${APT_DEPS} &&\
        curl https://bootstrap.pypa.io/get-pip.py | python /dev/stdin &&\
        pip install -I -r https://raw.githubusercontent.com/OCA/OCB/10.0/requirements.txt &&\
        pip install -I -r /tmp/requirements-lcc.txt &&\
        pip install simplejson WTForms &&\
        apt-get -y purge ${APT_DEPS} &&\
        apt-get -y autoremove &&\
        rm -rf /var/lib/apt/lists/* wkhtmltox.deb /tmp/requirements-lcc.txt

# Install Odoo from AwesomeFoodCoops repo
RUN set -x; \
        useradd --create-home --home-dir /opt/odoo --no-log-init odoo &&\
        /bin/bash -c "mkdir -p /opt/odoo/{etc,AwesomeFoodCoops,additional_addons,chouette_addons,data}" &&\
        git clone -b 9.0 --depth 1 https://github.com/AwesomeFoodCoops/odoo-production.git /opt/odoo/AwesomeFoodCoops &&\
        chown -R odoo:odoo /opt/odoo

# Install Odoo OCA and OpenWorx default dependencies
RUN set -x; \
        mkdir -p /tmp/oca-repos/ &&\
        git clone -b 9.0 --depth 1 https://github.com/OCA/account-financial-tools.git /tmp/oca-repos/account-financial-tools &&\
        mv /tmp/oca-repos/account-financial-tools/account_fiscal_year /opt/odoo/additional_addons/ &&\
        git clone -b 9.0 --depth 1 https://github.com/OCA/server-tools.git /tmp/oca-repos/server-tools &&\
        mv /tmp/oca-repos/server-tools/auto_backup /opt/odoo/additional_addons/ &&\
        git clone -b 9.0 --depth 1 https://github.com/Openworx/themes.git /tmp/chouette-repos/themes &&\
        mv /tmp/chouette-repos/themes/united_backend_theme /opt/odoo/additional_addons/united_backend_theme &&\
        rm -rf /tmp/oca-repos/ &&\
        find /opt/odoo/additional_addons/*/i18n/ -type f -not -name 'fr.po' -delete &&\
        chown -R odoo:odoo /opt/odoo 

# Install Odoo Specific addons used by La Chouette Coop
RUN set -x; \
        git clone -b 9.0 --depth 1 https://github.com/lachouettecoop/chouette-odoo-addons.git /opt/odoo/chouette_addons &&\
        git clone -b 9.0 --depth 1 https://bitbucket.org/lefilament/automatic_bank_statement_import.git /opt/odoo/additional_addons/automatic_bank_statement_import &&\
        chown -R odoo:odoo /opt/odoo 

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./odoo.conf /opt/odoo/etc/odoo.conf
RUN chown odoo:odoo /opt/odoo/etc/odoo.conf

# Mount /opt/odoo/data to allow restoring filestore
VOLUME ["/opt/odoo/data/"]

# Expose Odoo services
EXPOSE 8069

# Set default user when running the container
USER odoo

# Start
ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]

# Metadata
ARG VCS_REF
ARG BUILD_DATE
ARG VERSION
LABEL org.label-schema.schema-version="$VERSION" \
      org.label-schema.vendor=LaChouetteCoop \
      org.label-schema.license=Apache-2.0 \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.vcs-url="https://github.com/lachouettecoop/chouette-docker-odoo"

