# Change Log
All notable changes to this project will be documented in this file.
The Changelog was introduced on 2014-09-15, and is approximately in
accordance with [http://keepachangelog.com/](http://keepachangelog.com/).
I do my best to follow [Semantic Versioning](http://semver.org/).

## 3.0.0.beta - 2014-??-??
### Added
- Issue for 3.0 is at https://github.com/JoshCheek/seeing_is_believing/issues/47
- Added a [Changelog](Changelog.md) in accordance with [http://keepachangelog.com/](http://keepachangelog.com/)
- `seeing_is_believing/version` is required by default,
  you can now check your version by just typing `SeeingIsBelieving::VERSION` and running it.

### Changed
- Communication between SiB and the process running the code is no longer done by
  serializing the result with JSON. Now, there is an
  [EventStream](https://github.com/JoshCheek/seeing_is_believing/blob/4b9134ca45e001ebe5f139384bd1beee98b5e371/lib/seeing_is_believing/event_stream.rb)
  class, which will send the information back to the parent process as soon as it
  knows about it. For users who interact purely with the binary, this just means that
  JSON will not already be required.
- WrapExpressions' `before_all` and `after_all` keys now point to values that are lambdas with no args.
  Mostly this is for consistency since `before_each` and `after_each` are lambas,
  But also, because at some point I might want to provide an argument, and this will make it easier.
  And because it allows certain conveniences, such as setting local vars in the lambda.
- Loosened version constraints on parser dependency

### Removed
- Dependency on psych
- Remove HasException module. The only thing using it now is Result, so just relevant behaviour into there.
- SeeingIsBelieving::Line class
