{% set dir='/tmp/buildouttest' %}

copy-to-dir:
  file.recurse:
    - name: {{dir}}
    - source: salt://kiorky_blog_posts/b

buildout1:
  buildout.installed:
    - name: {{dir}}
    - require:
      - file: copy-to-dir

buildout2:
  buildout.installed:
    - name: {{dir}}
    - parts:
      - test2
    - require:
      - file: copy-to-dir

