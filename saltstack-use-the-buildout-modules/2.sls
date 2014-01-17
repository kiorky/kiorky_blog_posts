{% set dir='/tmp/buildouttest' %}


buildout3:
  buildout.installed:
    - name: {{dir}}
    - runas: vagrant
    - unless: test -e {{dir}}/.installed.cfg
