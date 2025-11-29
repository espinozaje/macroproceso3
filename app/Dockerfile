# Usamos una versión ligera de Python
FROM python:3.9-slim

# Creamos la carpeta de trabajo
WORKDIR /app

# Copiamos los archivos de tu compu al contenedor
COPY . .

# Instalamos las dependencias
RUN pip install -r requirements.txt

# El comando para encender el bot
CMD ["python", "app.py"]