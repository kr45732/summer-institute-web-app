# frozen_string_literal: true

require 'sinatra/base'
require 'logger'
require 'json'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :sessions

  attr_reader :logger, :groups

  def initialize
    super
    @logger = Logger.new('log/app.log')
    @groups ||= begin
      groups_from_id = `id`.to_s.match(/groups=(.+)/)[1].split(",").map do |g|
        g.match(/\d+\((\w+)\)/)[1]
      end

      groups_from_id.select { |g| g.match?(/^P\w+/) }
    end
  end

  def title
    'Summer Institute - Blender'
  end

  def project_root
    "#{__dir__}/projects"
  end

  def input_files_dir
    "#{project_root}/input_files"
  end

  def project_dirs
    Dir.children(project_root).reject { |dir| dir == "input_files"}.sort_by(&:to_s)
  end

  def configs
    configs = {}
    project_dirs.each { |dir| 
      if File.file?("projects/#{dir}/config.json")
        configs[dir] = JSON.parse(File.read("projects/#{dir}/config.json"))
      else
        FileUtils.rm_r("projects/#{dir}/")
      end
    }
    configs
  end

  def job_state(job_id)
    return "Not Started" if job_id.length == 0

    state = `/bin/squeue -j #{job_id} -h -o '%t'`.chomp
    s = {
      "" => "Completed",
      "R" => "Running",
      "C" => "Completed",
      "Q" => "Queued",
      "CF" => "Queued",
      "PD" => "Queued"
    }[state]
    
    s.nil? ? "Unknown" : s
  end

  def badge(state)
    {
      "" => "warning",
      "Unknown" => "warning",
      "Not Started" => "warning",
      "Running" => "success",
      "Queued" => "info",
      "Completed" => "primary"
    }[state.to_s]
  end

  def copy_upload(input: nil, output: nil)
    input_sha = Pathname.new(input).file? ? Digest::SHA256.file(input) : nil
    output_sha = Pathname.new(output).file? ? Digest::SHA256.file(output) : nil
    return if input_sha.to_s == output_sha.to_s

    File.open(output, 'wb') do |f|
      f.write(input.read)
    end
  end

  get '/' do
    logger.info('Requesting the index')
    @flash = session.delete("flash") || { info: 'Welcome to Summer Institute!' }
    @project_dirs = project_dirs
    @configs = configs
    erb :index
  end

  post "/" do
    logger.info(params.inspect)

    if params.key?("dir")
      dir = params["dir"]
      session["flash"] = {"info": "Deleted project: #{configs[dir]['name']}"}
      FileUtils.rm_r("#{project_root}/#{dir}/")
    else
      json = {}
      json["name"] = params["name"]
      if params.key?("icon") && params["icon"].length > 0
        json["icon"] = params["icon"]
      end
      File.open("#{project_root}/#{params['old_name']}/config.json", "w+") {|f| f.write(json.to_json) }

      stripped_name = params['name'].downcase.gsub(" ", "_")
      if params['old_name'] != stripped_name
        FileUtils.mv("#{project_root}/#{params['old_name']}", "#{project_root}/#{stripped_name}")
      end
      session["flash"] = {"info": "Modified project: #{params['name']}"}
    end
    redirect(url("/"))
  end

  get "/projects/:name" do
    name = params["name"]

    if name == "new" || name == "input_files"
      logger.info('Requesting the new project page')
      erb :new_project
    else
      logger.info("Displaying project: #{name}")

      @dir = Pathname("#{project_root}/#{name}")
      @flash = session.delete("flash")
      @uploaded_blend_files = Dir.glob("#{input_files_dir}/*.blend").map { |f| File.basename(f) }
      @project_name = configs[name]["name"]
      
      unless @dir.directory? || @dir.readable?
        session["flash"] = { danger: "#{@dir} does not exist" }
        redirect(url("/"))
      end

      @images = Dir.glob("#{@dir}/*.png")
      @frame_render_job_id = configs[name].fetch("frame_render_job_id", "")
      @frame_render_job_state = job_state(@frame_render_job_id)
      @frame_render_badge = badge(@frame_render_job_state)

      @video_render_job_id = configs[name].fetch("video_render_job_id", "")
      @video_render_job_state = job_state(@video_render_job_id)
      @video_render_badge = badge(@video_render_job_state)

      erb :show_project
    end
  end

  post "/projects/new" do
    logger.info("Creating a new project: #{params.inspect}")
    original_name = params["name"]
    name = original_name.downcase.gsub(" ", "_")
    project_dir = "#{project_root}/#{name}"
    project_dir.tap { |dir| FileUtils.mkdir_p(dir) }
    
    json = {}
    json["name"] = original_name
    if params.key?("icon") && params["icon"].length > 0
      json["icon"] = params["icon"]
    end
    File.open("#{project_dir}/config.json", "w+") {|f| f.write(json.to_json) }

    session["flash"] = {"info": "Made new project: #{original_name}"}
    redirect(url("/projects/#{name}"))
  end

  post "/render/frames" do
    logger.info("Trying to render frames with: #{params.inspect}")

    if params["blend_file"].nil?
      blend_file = "#{input_files_dir}/#{params['uploaded_blend_file']}"
    else
      blend_file = "#{input_files_dir}/#{params['blend_file']['filename']}"
      copy_upload(input: params['blend_file'][:tempfile], output: blend_file)
    end

    dir = params["dir"]
    basename = File.basename(blend_file, ".*")
    walltime = format("%02d:00:00", params["num_hours"])

    args = ['-J', "blender-#{basename}", '--parsable']
    args.concat ['--export', "BLEND_FILE_PATH=#{blend_file},OUTPUT_DIR=#{dir},FRAMES_RANGE=#{params[:frames_range]}"]
    args.concat ['-n', params[:num_cpus], '-t', walltime, '-M', 'pitzer']
    args.concat ['--output', "#{dir}/frame-render-%j.out"]
    args.concat ['--account', params["project_name"]]
    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/render_frames.sh 2>&1`

    job_id = output.strip.split(";").first
    name = dir.split('/').last
    json = configs[name]
    json["frame_render_job_id"] = job_id
    File.open("#{project_root}/#{name}/config.json", "w+") {|f| f.write(json.to_json) }
    
    session["flash"] = { info: "Submitted job #{job_id}"}
    redirect(url("/projects/#{dir.split('/').last}"))
  end

  post '/render/video' do
    logger.info("Trying to render video with: #{params.inspect}")

    output_dir = params["dir"]
    frames_per_second = params["frames_per_second"]
    walltime = format('%02d:00:00', params[:num_hours])

    args = ['-J', 'blender-video', '--parsable']
    args.concat ['--export', "FRAMES_PER_SEC=#{frames_per_second},FRAMES_DIR=#{output_dir}"]
    args.concat ['-n', params[:num_cpus], '-t', walltime, '-M', 'pitzer']
    args.concat ['--output', "#{output_dir}/video-render-%j.out"]
    args.concat ['--account', params["project_name"]]
    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/render_video.sh 2>&1`

    job_id = output.strip.split(';').first
    name = output_dir.split('/').last
    json = configs[name]
    json["video_render_job_id"] = job_id
    File.open("#{project_root}/#{name}/config.json", "w+") {|f| f.write(json.to_json) }

    session[:flash] = { info: "Submitted job #{job_id}"}
    redirect(url("/projects/#{output_dir.split('/').last}"))
  end

  get "/modify/:name" do
    @config = configs[params["name"]]
    @config["old_name"] = params["name"]
    logger.info(@config.inspect)
    erb :modify_project
  end

  get "/api/job_state/:job_id" do
    content_type :json
    {job_state: job_state(params["job_id"])}.to_json
  end
end
