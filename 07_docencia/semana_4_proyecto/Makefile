# Prototipo causal local — semana 4 (make <objetivo>)
.PHONY: verificar estimar registrar ventanas servir humo demo limpiar

verificar:          ## esquema C-01 + hashes de splits + la pared
	python3 datos.py

estimar:            ## ATE + IC + diagnósticos + estimacion.json
	python3 estimacion.py

registrar:          ## tarjeta + versión v0001 + champion + demo de mutación
	python3 registro.py

ventanas:           ## tres ventanas -> pasa / alerta / falla
	python3 monitor.py

servir:             ## levanta el servicio (Ctrl-C para parar)
	uvicorn servicio:app --port 8000

humo:               ## prueba de humo del servicio
	python3 humo.py

demo: verificar estimar registrar ventanas humo  ## el flujo completo

limpiar:            ## borra artifacts (las versiones son regenerables)
	rm -rf artifacts
