import subprocess
import time
from datetime import datetime

def probar_servidor (host):
    # "" Realiza un ping a un host, mide el tiempo de respuesta y maneja excepciones del sistema. ""
    inicio = time.time ()
    try:
        # ejecutamos el ping (3 segundos de timeout maximo)
        resultado = subprocess.run(
             ["ping","-c","1","-w", "5000",host],
                capture_output=True,
                text=True,
                timeout=8)
        fin =time.time()
        latencia_ms = round((fin-inicio) * 1000,2)
    # Devuelve True si el comando fue exitoso (codigo de salida 0)
        exito = (resultado.returncode == 0)
        return exito, latencia_ms
    except subprocess.TimeoutExpired:
        # Ocurre si el servidor tarda mas de 5s en responder
        return False, None
    except Exception as e:
        # Captura cualquier otro erro del sistema sin romper el script
        print(f"[ERROR DEL SISTEMA]: {e}")
        return False, None

def registrar_log(mensaje):
    """ Escribe un evento con marca de tiempo en un archivo local monitor.log"""
    ahora = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    linea_log = f"[{ahora}] {mensaje}\n"
    # 'a' significa Append (agregar al final sin sobrescribir)
    with open("monitor.log","a", encoding="utf-8") as archivo:
        archivo.write(linea_log)
\
mis_servidores = ["www.tibia.com","www.google.com","8.8.8.8"]
for servidor in mis_servidores:
    print(f"Probando {servidor}...")
    exito, latencia = probar_servidor(servidor)

    if exito:
        mensaje = f"OK: {servidor} responde en {latencia} ms"
        print (f" [EXITO] {mensaje}")
        registrar_log(mensaje) # Guardalo en el archivo log

    else:
        mensaje = f"ALERTA: {servidor} no responde o supero el tiempo de espera"
        print(f" [FALLO] {mensaje}")
        registrar_log(mensaje)  # Guardalo en el archivo log

print("Escaneo de servidores finalizado. Revisa monitor.log para mas detalles.")
