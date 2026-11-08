"""Test doubles for the LiteRT interpreter (used where LiteRT is not needed)."""

import numpy as np


class FakeInterpreter:
    """Mimics the parts of ai_edge_litert.interpreter.Interpreter that MangGrade uses.

    By default it returns a softmax over four values derived from the mean
    red, green and blue of the input, so different images give different but
    always valid probabilities.
    """

    def __init__(self, model_path=None, input_shape=(1, 224, 224, 3), output_shape=(1, 4),
                 input_dtype=np.float32, output_fn=None, fail_invoke=False):
        self.model_path = model_path
        self.input_shape = np.array(input_shape)
        self.output_shape = np.array(output_shape)
        self.input_dtype = input_dtype
        self.output_fn = output_fn
        self.fail_invoke = fail_invoke
        self.invocations = 0
        self._input = None
        self._output = None

    def allocate_tensors(self):
        pass

    def get_input_details(self):
        return [{"index": 0, "shape": self.input_shape, "dtype": self.input_dtype,
                 "quantization": (0.0, 0)}]

    def get_output_details(self):
        return [{"index": 7, "shape": self.output_shape, "dtype": np.float32,
                 "quantization": (0.0, 0)}]

    def set_tensor(self, index, value):
        assert index == 0
        self._input = np.array(value, copy=True)

    def invoke(self):
        if self.fail_invoke:
            raise RuntimeError("simulated interpreter failure")
        self.invocations += 1
        if self.output_fn is not None:
            self._output = np.asarray(self.output_fn(self._input), dtype=np.float32).reshape(1, -1)
            return
        means = self._input.reshape(-1, 3).mean(axis=0) / 64.0
        logits = np.array([means[0], means[1], means[2], 1.0])
        exp = np.exp(logits - logits.max())
        self._output = (exp / exp.sum()).astype(np.float32).reshape(1, 4)

    def get_tensor(self, index):
        assert index == 7
        return self._output


def fake_factory(**kwargs):
    """Return an interpreter_factory that builds FakeInterpreter(**kwargs)."""
    created = []

    def factory(model_path):
        interpreter = FakeInterpreter(model_path=model_path, **kwargs)
        created.append(interpreter)
        return interpreter

    factory.created = created
    return factory
