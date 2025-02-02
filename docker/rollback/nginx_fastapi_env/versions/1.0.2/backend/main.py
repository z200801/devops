from fastapi import FastAPI
import socket

app = FastAPI()

@app.get("/")
def read_root():
    hostname = socket.gethostname()
    return {"message": "Hello from Backend!", "hostname": hostname}

@app.get("/status")
def get_status():
        return {"status": "healthy", "version": "1.0.2"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

