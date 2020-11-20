#!/usr/bin/env ruby

require 'bundler'
Bundler.require

require 'json'

class OrphanRemover
  ACCEPT_JSON = { 'Accept' => 'application/json' }.freeze
  MYTH_SERVICES = "http://localhost:6544"
  STORAGE_GROUPS = %[LiveTV Default]
  RECORDING_REGEX = /^\d{4}_\d{14}/

  def initialize
    @storage_directories = nil
    @files = nil
  end

  def storage_directories
    @storage_directories ||= begin
      storage_call = Excon.get(File.join(MYTH_SERVICES, 'Myth', 'GetStorageGroupDirs'), headers: ACCEPT_JSON)

      json = JSON.parse(storage_call.body)

      json['StorageGroupDirList']['StorageGroupDirs'].select {|sg| STORAGE_GROUPS.include? sg['GroupName'] }.collect {|sg| sg['DirName']}
    end
  end

  def recordings
    @recordings ||= begin
      recording_call = Excon.get(File.join(MYTH_SERVICES, 'Dvr', 'GetRecordedList'), headers: ACCEPT_JSON)

      json = JSON.parse(recording_call.body)

      json['ProgramList']['Programs'].collect {|program| program['FileName']}
    end
  end

  def orphaned_recording_files
    asset_hash.keys.difference(recordings)
  end

  def recording_records_with_no_files
    recordings.difference(asset_hash.keys)
  end

  def files
    @files ||= begin
      storage_directories.collect {|d| Dir.entries(d) }.flatten.select {|y| y.match? RECORDING_REGEX}.sort
    end
  end

  def asset_hash
    @asset_hash ||= begin
      files.each_with_object({}) do |filename, hash|
        base = filename.split(".")[0..1].join(".")
        hash[base] ||= []
        hash[base] << filename
      end
    end
  end

  def assets_without_recordings
    @assets_without_recordings ||= begin
      asset_hash.each_with_object([]) do |recording, basenames|
        base = recording[0]
        files = recording[1]
        basenames << base unless files.include? base
      end
    end
  end
end

orphan_remover = OrphanRemover.new
puts "Evaluating files in these directories:"
puts orphan_remover.storage_directories

puts "assets without recordings"
puts orphan_remover.assets_without_recordings

puts "orphaned recording files"
puts orphan_remover.orphaned_recording_files

puts "orphaned recording records"
puts orphan_remover.recording_records_with_no_files
