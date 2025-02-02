from fastapi import FastAPI
import socket
import os

app = FastAPI()

# Get version from environment variable with default value
VERSION = os.getenv("STACK_VERSION", "unknown")

@app.get("/")
def read_root():
    hostname = socket.gethostname()
    return {
        "message": "Hello from Backend!", 
        "hostname": hostname,
        "version": VERSION
    }

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "version": VERSION
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
