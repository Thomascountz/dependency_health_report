## Core Design Principles

The design of Ruby project code should express an opinion about software writing through three prioritizations: correctness over comprehensiveness, maintainability over performance, and explicitness over neatness.

These principles can be used to define style guides and Rubocop configurations for Ruby projects.

### Correctness over comprehensiveness

Ruby projects should focus on implementing core functionality correctly and safely, rather than attempting to cover every possible edge case or feature. This approach prioritizes building a solid foundation with well-tested, reliable components over trying to support every conceivable use case from the start. This comes at the cost of implementing all possible features immediately, but ensures that the features that are implemented work correctly and can serve as a stable base for future expansion.

### Maintainability over performance

This principle defines "maintainability" as the qualitative level of cognitive effort required to modify a particular piece of code. Well-designed code should allow modifications to specific functionality without requiring deep understanding of unrelated components. The only relation to "performance" is that psychologically, it can be the case that we design abstractions and couple things together for the sake of "performance," and it's this urge that code should explicitly resist. Furthermore, "performance" is in quotes because it cannot be defined in a vacuum—it requires a _real world_ measurement. Even with this, forsaking maintainability for performance is never a given.

### Explicitness over neatness

Ruby's expressiveness and flexibility can introduce accidental complexity when developers prioritize clever or concise code over clear intent. Code standards should purposely favor explicitness and verbosity over consciousness. For example, `if-else` statements are preferred over post-fix conditionals, `if-else` statements should always include an explicit `else` branch, temporary variables are preferred for holding intermediate values, and so on. Ruby's expressiveness permits this kind of verbosity, and it should be embraced for the sake of clarity and maintainability.
