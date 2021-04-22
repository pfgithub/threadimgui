const DevtoolsOpts = struct {
    renderContentFn: fn () RenderResult,
    // this has to be passed in data from the root of the render thing, not the current level
    // conditional rendering of stuff wrapped in containers is a bit complicated but at least
    // it's possible unlike in react
};

pub fn renderDevtools(opts: DevtoolsOpts) RenderResult {}
