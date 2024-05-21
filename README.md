# Simple variable-latency coprocessor
This is a totally useless coprocessor designed to test the performance of CPU and other drivers when offloading tasks to multi-cycles, iterative or pipelined, execution units. Or to waste power.

## Main features
The coprocessor accepts two operands, `rs1` and `rs2`. `rs1` is propagated unchanged to the output, while the lower bits or `rs2` are used to set the coprocessor latency. A control signal `ctl_i` is used to switch between _iterative_ and _pipelined_ modes:
- _Iterative mode_: the coprocessor supports a single in-flight operation at a time. After accepting a request transaction (`valid_i` and `ready_o` both asserted), it won't accept any subsequent operation until the current one is complete (`ready_o` low). This mode emulates serial execution units like dividers and vector coprocessors. `rs2` controls the number of cycles required to produce the result (i.e., `rs1`) at the output of the coprocessor.
- _Pipelined mode_: the coprocessor can accept multiple outstanding requests, that are processed in pipeline. If, in any cycle, the consumer can not accept the result (`ready_i` low), the entire pipeline is stalled. `rs2` defines the pipeline stage where the result is fetched from. The actual number of pipeline registers (i.e., maximum latency) is a compile-time parameter. This mode emulates pipelined execution units like multipliers and application-specific feed-forward dataflow architectures like filters.

## TODO
- [ ] Wrapper for the CORE-V extension interface and instruction definitions.
