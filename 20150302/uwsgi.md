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

Then in the vhost, we can add
A section to serve tiles
```
```

A section to enable routing down to the worker by relying on the retcode from the mapped variables?

```
```
This will ensure that only the expected request can go down to the uwsgi worker, as you know,
mapserver can also take an arbitrary mapfile path, and be a security breach.

And another related section to do the real stuff
```
```

Which give us finally:
```
```

## The uwsgi worker
In debian like, you will have to add a file /etc/uwsgi/app-available & symlink it in app-enabled.
The content of this file will look like
```
```

And now, TaDa:
```
curl -vvv ""
```


## Digression, the uwsgi protocol
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
curl -vvvv http://foo.net/cgi-bin/mapserv?map=mymap
```
- from another terminal:
```
tcpdump port 3031 -vvvvv -XX -i lo
        ...
        foo.net.53278 > foo.net.3031: ...
        0x0000:  0000 0000 0000 0000 0000 0000 0800 4500  ..............E.
        0x0010:  0293 05d0 4000 4006 3493 7f00 0001 7f00  ....@.@.4.......
        0x0020:  0001 d01e 0bd7 db95 dd53 e98e a99f 5018  .........S....P.
        0x0030:  0056 0088 0000 0067 0200 0c00 5155 4552  .V.....g....QUER
        ...
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
 We can now inspect what we could have fuck under the hood.

And we clearly saw that we were missing to tell to uwsgi to switch over the cgi plugin from nginx.
Thus, we just needed, to.

## digression with gunicorn
Even if we could made separation of concerns by using uwsgi as our python app router of choice, we
don't for now.
Indeed, our policy for python workers (django, pyramid, flask & etc) is still recommend the use of gunicorn
as it is fast, reliable, scalable and still in python, which make debugging apps really simpler and straighforward.
