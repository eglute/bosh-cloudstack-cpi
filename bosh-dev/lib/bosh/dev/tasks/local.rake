namespace :local do
  desc 'build a Stemcell locally'
  task :build_stemcell, [:infrastructure_name, :operating_system_name, :agent_name] do |_, args|
    require 'bosh/dev/stemcell_builder'

    stemcell_builder = Bosh::Dev::StemcellBuilder.new(
      ENV.to_hash,
      Bosh::Dev::Build::Local.new(ENV['CANDIDATE_BUILD_NUMBER'], Bosh::Dev::LocalDownloadAdapter.new(Logger.new(STDERR))),
      Bosh::Stemcell::Definition.for(
        args.infrastructure_name, args.operating_system_name, args.agent_name))
    stemcell_path = stemcell_builder.build_stemcell

    mkdir_p('tmp')
    cp(stemcell_path, File.join('tmp', File.basename(stemcell_path)))
  end
end
