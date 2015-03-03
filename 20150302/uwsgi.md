# Installing mapserver with nginx & uwsgi



## Intro
Nowodays, apache httpd can be considered as a great fossil.
Bu how comes when you want to drop some old things in you infra, like cgi's ?
That's the case when we want to publish out some shapefiles via mapserver.
And, yes with the plain old school mapserv cgi.

Hopefully, we won't have to get apache back because we have a ubersecret :
[uwsgi](https://uwsgi-docs.readthedocs.org/en/latest/), the savior.



## Prerequisites
The first thing is to install mapserv, nginx & uwsgi.
I can't more than highly recommand to use a decent version of nginx(1.6/1.7) & mapserver.
Your nginx must have the uwsgi module built with.

Makina-Corpus even use their [own ppa](https://launchpad.net/~makinacorpus/+archive/ubuntu/nginx)
of it (1.7.10 at the time of this article writing).

For mapserver, you can use [ubuntugis unstable](https://launchpad.net/~ubuntugis/+archive/ubuntu/ubuntugis-unstable).

After the repositories configuration, you can eventually install the softwares
```
apt-get install mapserv uwsgi nginx
```

## Maps layout
When you have at least all of those 3 prerequisites, you ll have to la
y down your served maps on the filesystem
An example here:
```
/data/tmp
/data/maps/map/map.map
/data/maps/map/layer/Layer.dbf
/data/maps/map/layer/Layer.prj
/data/maps/map/layer/Layer.sbn
/data/maps/map/layer/Layer.sbx
/data/maps/map/layer/Layer.shp
/data/maps/map/layer/Layer.shx
```

Don't forget to reference shape in your top section in the mapfile:
```
MAP
  SHAPEPATH "/data/maps"
```

Don't forget to reference images path in your WEP section in the mapfile:
```
WEB
  IMAGEPATH "/data/tmp"
  IMAGEURL "http://foo.net/tiles"
END
```

## NGINX Vhost
The first thing is to add to the server, some mapped variables that will route
our requests down to the uwsgi worker
```
map $args $mapname {
    default: myapp;
    "~*(\?|&)?map=myapp(&?|$)" myapp;
}

map $args $mapfile {
    default: /srv/projects/myapp/data/maps/myapp/map.map;
    "~*(\?|&)?map=myapp(&?|$)" /srv/projects/myapp/data/maps/myapp/map.map;
}

map $args $maproot {
    default: /srv/projects/myapp/data/static;
    "~*(\?|&)?map=myapp(&?|$)" /srv/projects/myapp/data/maps;
}

map $args $mapgo {
    default: 0;
    "~*(\?|&)?map=myapp(&?|$)" 1;
}
```

Then in the vhost, we can add a section to serve tiles
```
location /tiles/ {
     alias /srv/projects/myapp/data/tmp;
}
```

Then a section to enable routing down to the worker by relying on the retcode from the mapped variables?
```
location /cgi-bin/mapserv {
  error_page 420 = @mapserv;
  if ( $mapgo = "1" ) {
   return 420;
  }
}
```

This will ensure that only the expected request can go down to the uwsgi worker, as you know,
mapserver can also take an arbitrary mapfile path, and be a security breach.

And another related section to do the real stuff
```
location @mapserv {
   include uwsgi_params;
   uwsgi_modifier1 9;
   uwsgi_param UWSGI_SETENV $mapname=$mapfile;
   uwsgi_param UWSGI_SETENV MS_MAPFILE=$mapfile;
   uwsgi_param UWSGI_SETENV MS_MAP_NO_PATH=no;
   uwsgi_pass unix:///srv/projects/myapp/data/socket;
}
```

Which give us finally:
```
map $args $mapname {
    default: myapp;
    "~*(\?|&)?map=myapp(&?|$)" myapp;
}

map $args $mapfile {
    default: /srv/projects/myapp/data/maps/myapp/map.map;
    "~*(\?|&)?map=myapp(&?|$)" /srv/projects/myapp/data/maps/myapp/map.map;
}

map $args $maproot {
    default: /srv/projects/myapp/data/static;
    "~*(\?|&)?map=myapp(&?|$)" /srv/projects/myapp/data/maps;
}

map $args $mapgo {
    default: 0;
    "~*(\?|&)?map=myapp(&?|$)" 1;
}

server {
  listen 80;
  server_name foo.net;
  server_name_in_redirect on;
  error_log /var/log/nginx/foo-error.log crit;
  access_log  /var/log/nginx/foo-access.log custom_combined;
  root /srv/projects/myapp/data/static;
  location /tiles/ {
      alias /srv/projects/myapp/data/tmp;
  }
  location /static/ {
      alias /srv/projects/myapp/data/static/;
  }
  location /cgi-bin/mapserv {
    error_page 420 = @mapserv;
    # debug map via headers
    # more_set_headers "X-MAPSERV-MAPTEST: $mapgo";
    # more_set_headers "X-MAPSERV-MAPFILE: $mapfile";
    # more_set_headers "X-MAPSERV-MAPNAME: $mapname";
    # more_set_headers -s 404 "X-MAPSERV-MAPTEST: $mapgo";
    # more_set_headers -s 404 "X-MAPSERV-MAPFILE: $mapfile";
    # more_set_headers -s 404 "X-MAPSERV-MAPNAME: $mapname";
    if ( $mapgo = "1" ) {
     return 420;
    }
  }
  location @mapserv {
      include uwsgi_params;
      uwsgi_modifier1 9;
      uwsgi_pass 127.0.0.1:3031;
      uwsgi_param UWSGI_SETENV $mapname=$mapfile;
      uwsgi_param UWSGI_SETENV MS_MAPFILE=$mapfile;
      uwsgi_param UWSGI_SETENV MS_MAP_NO_PATH=no;
      uwsgi_pass unix:///srv/projects/myapp/data/socket;
  }
}
```



## The uwsgi worker
In debian like, you will have to add a file /etc/uwsgi/app-available & symlink it in app-enabled.
The content of this file will look like:
```
[uwsgi]
master = true
plugins = cgi
#async = 20
#ugreen = True
threads = 5
socket = /srv/projects/myapp/data/socket
uid = www-data
gid = www-data
cgi = /usr/bin/mapserv
```

And now, TaDa:
```
curl -vvv 'http://foo.net/cgi-bin/mapserv?map=mymap&VERSION=1.3.0&SERVICE=WMS&REQUEST=GetCapabilities'
...

<?xml version='1.0' encoding="ISO-8859-1" standalone="no" ?>
<WMS_Capabilities version="1.3.0"...>
<!-- MapServer version 6.4.1...-->
<Service>
```

## Note about uwsgi protocol
At first, we got a 502 from the above setup, the first thing we did, to use setup
was to temporary enable plain tcp communcation (no socket) between nginx and uwsgi.
nginx
```
uwsgi_pass 127.0.0.1:3031;
```

uwsgi
```
socket = localhost:3031
```

Then restart nginx, stop uwsgi emperor, and run only our worker, in foreground (non daemonized)
```
service nginx restart
service uwsgi stop
uwsgi /etc/uwsgi/apps-enabled/config.ini
```

We can also increase nginx logging, and tail -f it's logs on another terminal:
edit nginx configuration:
```
error_log /foo.log debug;
```

And then issue
```
service nginx restart
tail -f /foo.log
```

Then, we can finally do the capture of a map request:

- from one terminal:

```
curl -vvvv 'http://foo.net/cgi-bin/mapserv?map=mymap&VERSION=1.3.0&SERVICE=WMS&REQUEST=GetCapabilities'
...

<?xml version='1.0' encoding="ISO-8859-1" standalone="no" ?>
<WMS_Capabilities version="1.3.0"...>
<!-- MapServer version 6.4.1...-->
<Service>
```
- from another terminal:
```
tcpdump port 3031 -vvvvv -XX -i lo
        ...
        foo.net.53278 > foo.net.3031: ...
        0x0000:  0000 0000 0000 0000 0000 0000 0800 4500  ..............E.
        0x0010:  0293 45b3 4000 4006 f4af 7f00 0001 7f00  ..E.@.@.........
        0x0020:  0001 eae4 0bd7 f33f 9714 6a07 fbc9 5018  .......?..j...P.
        0x0030:  0056 0088 --> 00 <-- 00 0067 0200 0c00 5155 4552  .V.....g....QUER
```
- And the following bits in uwsgi:
```
-- unavailable modifier requested: 0 --
```
- And see that the first uwsgi stuff, nginx side is
```
2015/03/03 17:58:59 [debug] 1525#0: *3 uwsgi param: "QUERY_STRING: map=mymap"
2015/03/03 17:58:59 [debug] 1525#0: *3 uwsgi param: "REQUEST_METHOD: GET"
```

After a dig in [Reading The Great Fucking protocol RFC](http://uwsgi-docs.readthedocs.org/en/latest/Protocol.html),
 We can now inspect what we could have fuck under the hood, and see that the **modifier1** is wrong (0 instead of 9).

And we clearly saw that we were missing to tell to uwsgi to switch over the cgi plugin from nginx.
Thus, we just needed, to ajust in nginx config, in the handler part, before the uwsgi_pass
```
location @mapserv {
    ...
    uwsgi_modifier1 9;
    uwsgi_pass 127.0.0.1:3031;
    ...
}
```

Now the capture shown a correct **09** **modifier1**.
```
        foo.net.53422 > foo.net.3031: ...
        0x0000:  0000 0000 0000 0000 0000 0000 0800 4500  ..............E.
        0x0010:  0292 643c 4000 4006 d627 7f00 0001 7f00  ..d<@.@..'......
        0x0020:  0001 d0ae 0bd7 dd2a a5ab ce25 41fe 5018  .......*...%A.P.
        0x0030:  0056 0087 0000 --->09<---66 0200 0c00 5155 4552  .V.....f....QUER
```

And a WMS *GetCaps* should work
```
curl 'http://foo.net/cgi-bin/mapserv?map=mymap&VERSION=1.3.0&SERVICE=WMS&REQUEST=GetCapabilities'
...
<?xml version='1.0' encoding="ISO-8859-1" standalone="no" ?>
<WMS_Capabilities version="1.3.0"...>
<!-- MapServer version 6.4.1...-->
<Service>
...
```



## Words about  gunicorn
Even if we could made separation of concerns by using uwsgi as our python app router of choice, we
don't for now.
Indeed, our policy for python workers (django, pyramid, flask & etc) is still recommend the use of gunicorn
as it is fast, reliable, scalable and still in python, which make debugging apps really simpler and straighforward.
