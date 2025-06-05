local Config = {}

Config.API_BASE_URL = 'https://gallery-go-backend-223066796377.us-central1.run.app'
Config.SOURCE_HEADER = 'APP'
Config.BATCH_SIZE = 20
Config.MAX_RETRIES = 3
Config.INITIAL_BACKOFF = 1 -- seconds

return Config