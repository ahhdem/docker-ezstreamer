# ezstream in Docker

## Run

Run with default password, export port 8000

```bash
docker run -p 8000:8000 ahhdem/docker-ezstreamer
$BROWSER localhost:8000
```

Run with custom password

```bash
docker run -p 8000:8000 -e ICECAST_SOURCE_PASSWORD=aaaa -e ICECAST_ADMIN_PASSWORD=bbbb -e ICECAST_PASSWORD=cccc -e ICECAST_RELAY_PASSWORD=dddd ahhdem/docker-ezstreamer
```

Run with custom configuration

```bash
docker run -p 8000:8000 -v /path/to/config:/config -v /path/to/logs:/var/log/ezstreamer ahhdem/docker-ezstreamer
```

Extends Dockerfile

```Dockerfile
FROM ahhdem/docker-ezstreamer
ADD ./ezstream.xml /etc/ezstream.xml
```

Docker-compose

```yaml
ezstreamer:
  image: ahhdem/docker-ezstreamer
  volumes:
  - logs:/var/log/ezstreamer
  - /etc/localtime:/etc/localtime:ro
  environment:
  - ICECAST_SOURCE_PASSWORD=aaa
  - ICECAST_ADMIN_PASSWORD=bbb
  - ICECAST_PASSWORD=ccc
  - ICECAST_RELAY_PASSWORD=ddd
  - ICECAST_LOCATION=Earth
  - ICECAST_ADMIN=john@doe.com
  - ICECAST_HOSTNAME=stream.doe.com
  ports:
  - 8000:8000
```

## License

[MIT](https://github.com/ahhdem/docker-ezstreamer/blob/master/LICENSE.md)
