# ezstream in Docker

## Run

Run with default password, export port 8000

```bash
docker run -p 8000:8000 ahhdem/docker-ezstreamer
$BROWSER localhost:8000
```

Run with custom password

```bash
docker run -p 8000:8000 -e STREAM_PASSWORD=aaaa -e STREAM_PASSWORD=bbbb ahhdem/docker-ezstreamer
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
  - /path/to/your/media:/media
  environment:
  - STREAM_PASSWORD=ccc
  - STREAM_LOCATION=Earth
  - STREAM_ADMIN=john@doe.com
  - STREAM_HOSTNAME=stream.doe.com
  - STREAM_PORT
```

## License

[MIT](https://github.com/ahhdem/docker-ezstreamer/blob/master/LICENSE.md)
