# Contributing
First off, thank you for considering contributing to Philomena. It's people like you that make Philomena such a great imageboard software.
Following these guidelines helps to communicate that you respect the time of the developers managing and developing this open source project. In return, they should reciprocate that respect in addressing your issue, assessing changes, and helping you finalize your pull requests.

We are a free/libre open source project and we love to receive contributions from our community — you! There are many ways to contribute, from writing reviews or blog posts, improving the documentation, submitting bug reports and feature requests or writing code which can be incorporated into the project itself.

## Open Development
All work on Philomena happens directly on GitHub. Both core team members and external contributors send pull requests which go through the same review process.

## Branch Organization
We will do our best to keep the branch `master` in good shape, with tests passing at all times. But in order to move fast, we will make changes that your custom changes might not be compatible with. We recommend that you use the latest code from branch `master`. Please use feature branches when working on more complex changes, so others can follow and contribute, too.

If you send a pull request, please do it against the branch `master`.

## How to suggest a feature or enhancement
Please, use the [issue tracker](https://github.com/booru/philomena/issues) to report feature requests and bugs.
If your problem is not strictly Philomena specific, there are also a couple of forums out there regarding imageboards.

## Responsibilities

- Ensure cross-platform compatibility and standard compliance for every change that's accepted. The majorly used webbrowsers should all support the features.
- Ensure that code that goes into master branch meets all requirements from the requirements list below
- Create issues for any major changes and enhancements that you wish to make. Discuss things transparently and get community feedback.
- Don't add any code or dependencies to the codebase unless needed. Try to keep it simple and reduce maintenance overhead.
- Keep feature versions as small as possible, preferably one new major feature per version. This also applies to git commits.
- Be welcoming to newcomers and encourage diverse new contributors from all backgrounds. See the [Contributor Covenant](https://www.contributor-covenant.org/) Community Code of Conduct.
- Take the time to get things right. Pull Requests (PR) almost always require additional improvements to meet the bar for quality. Be very strict about quality. This usually takes several commits on top of the original PR.
- Update documentation where necessary, write documentation when required. Use markdown files in the top folder of the repository when targeting users of this software. Write green code or markdown files located next to the described code when targeting other developers.

## Requirements for code contributions to master branch
- Try to only contribute working code, no dead code, no "soon to be used" code and no "will fix it soon" code
- No huge methods, try to reduce complexity, write readable code -> see [Clean Code Cheat Sheet](https://www.planetgeek.ch/wp-content/uploads/2014/11/Clean-Code-V2.4.pdf)
- When copying others peoples/projects code, check licenses. Add license documentation to this repository where needed.

## Code Style 
TODO describe code style rules, word capitalization rules and so on here

```
TODO add sample code with valid syntax here
```

## Repository Folder Structure
The current folder structure is just a first draft, and you are encouraged to improve it..

Prefer all lowercase letters to name folders.

The current folder structure is TODO

| Where | What |
|---|---|
| / | Main repo folder. Try to not add any new files here, but instead place them in a fitting subfolder. |
| /TODO/ | Sample description of an important location / folder in this repo. |

## Project Insights

### Tests

At every push to branch `master` or a pull request targeting that branch, 
TODO describe how to run tests, how to write tests

### Customization Entry Point For Developers

### Docker Setup Documentation

### Internationalization (I18N)

So far no effort was done to support internationalization in philomena. If you want to work on this, please feel free to create a draft pull request of your prelimiary results, so we can work together and thus better improve the software.
