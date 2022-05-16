local-redis-docker:
	-docker network create -d bridge redisnet
	-docker run --rm -d -p 6379:6379 --name kvstore --network redisnet redis
