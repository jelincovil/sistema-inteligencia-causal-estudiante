PY ?= python3
TEST_PYTHONPATH = src:B1_servicio_dml:B3_servicio_policy:B4_monitoreo_causal

.PHONY: validate test demo monitor

validate: test
	"$(PY)" -m compileall -q src B1_servicio_dml B2_model_card_ci B3_servicio_policy B4_monitoreo_causal

test:
	PYTHONPATH=$(TEST_PYTHONPATH) "$(PY)" -m unittest discover -v -s tests
	PYTHONPATH=$(TEST_PYTHONPATH) "$(PY)" -m unittest discover -v -s B1_servicio_dml/tests
	PYTHONPATH=$(TEST_PYTHONPATH) "$(PY)" -m unittest discover -v -s B3_servicio_policy/tests
	PYTHONPATH=$(TEST_PYTHONPATH) "$(PY)" -m unittest discover -v -s B4_monitoreo_causal/tests

demo:
	PYTHONPATH=src "$(PY)" scripts/run_demo.py

monitor:
	"$(PY)" B4_monitoreo_causal/scripts/run_monitor.py
