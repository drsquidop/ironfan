require 'cluster_chef/dsl_object'
require 'cluster_chef/cloud'
require 'cluster_chef/security_group'
require 'cluster_chef/compute'
require 'chef'

module ClusterChef
  Chef::Config[:clusters] ||= {}
  Chef::Config[:cluster_path] ||=  [ File.join(Chef::Config[:cluster_chef_path], "clusters") ]

  def self.connection
    @connection ||= Fog::Compute.new({
        :provider              => 'AWS',
        :aws_access_key_id     => Chef::Config[:knife][:aws_access_key_id],
        :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key],
        #  :region                => region
      })
  end

  def self.servers
    @servers ||=  ClusterChef.connection.servers.all
  end

  def self.servers_for_cluster cluster
    cluster_group = cluster.cluster_name

  end

  def self.servers_for_facet facet
    cluster_name = facet.cluster_name
    facet_name = facet.facet_name
    facet_group = "#{cluster_name}-#{facet_name}"
    servers.select {|s| s.groups.index( facet_group ) }
  end

  def self.load_cluster cluster_name
    raise ArgumentError, "Please supply a cluster name" if cluster_name.to_s.empty?
    begin
      Chef::Config[:cluster_path].each do |path|
        cluster_path = File.join( path, "#{cluster_name}.rb" )
        next unless File.exists?(cluster_path)
        require cluster_path
        break
      end
    rescue Exception => e
      $stderr.puts "Error when loading cluster #{cluster_name}"
      $stderr.puts e
      exit -1
    end
    
    return clusters[cluster_name] if clusters[cluster_name]
    
    $stderr.puts "Unable to locate the cluster definition for #{cluster_name}."
    $stderr.puts "Cluster_path: [ #{ Chef::Config[:cluster_path].join(", ")} ]"
  
    exit -1

  end

  def self.running_servers
  end

  def self.clusters
    Chef::Config[:clusters]
  end

  def self.cluster name, &block
    cl = self.clusters[name] ||= ClusterChef::Cluster.new(name)
    cl.instance_eval(&block) if block
    cl
  end

  #
  # From chef, find each node by its cluster_name
  #
  def self.find_chef_by_cluster_name
    # cluster_name:*
  end

  #
  # From fog, find each node and match cluster_facets against security groups
  #


  def self.cluster_facets
    clusters.map{|cluster_name, cl| cl.facets.map{|facet_name, f| "#{cluster_name}-#{facet_name}" }}.flatten
  end
end
