require 'molinillo/dependency_graph'

module Pod
  class Installer
    class Analyzer
      # Generates dependencies that require the specific version of the Pods
      # that haven't changed in the {Lockfile}.
      module LockingDependencyAnalyzer
        class << self; attr_accessor :pods_to_unlock; end

        # Generates dependencies that require the specific version of the Pods
        # that haven't changed in the {Lockfile}.
        #
        # These dependencies are passed to the {Resolver}, unless the installer
        # is in update mode, to prevent it from upgrading the Pods that weren't
        # changed in the {Podfile}.
        #
        # @return [Molinillo::DependencyGraph<Dependency>] the dependencies
        #         generated by the lockfile that prevent the resolver to update
        #         a Pod.
        #
        def self.generate_version_locking_dependencies(lockfile, pods_to_update, pods_to_unlock = nil)
          self.pods_to_unlock = pods_to_unlock
          dependency_graph = Molinillo::DependencyGraph.new

          if lockfile
            explicit_dependencies = lockfile.to_hash['DEPENDENCIES'] || []
            explicit_dependencies.each do |string|
              dependency = Dependency.new(string)
              dependency_graph.add_vertex(dependency.name, nil, true)
            end

            pods = lockfile.to_hash['PODS'] || []
            pods.each do |pod|
              add_to_dependency_graph(pod, [], dependency_graph)
            end

            pods_to_update = pods_to_update.flat_map do |u|
              root_name = Specification.root_name(u).downcase
              dependency_graph.vertices.keys.select { |n| Specification.root_name(n).downcase == root_name }
            end

            pods_to_update.each do |u|
              dependency_graph.detach_vertex_named(u)
            end
          end

          dependency_graph
        end

        # Generates a completely 'unlocked' dependency graph.
        #
        # @return [Molinillo::DependencyGraph<Dependency>] an empty dependency
        #         graph
        #
        def self.unlocked_dependency_graph
          Molinillo::DependencyGraph.new
        end

        private

        def self.add_child_vertex_to_graph(dependency_string, parents, dependency_graph)
          dependency = Dependency.from_string(dependency_string)
          if self.pods_to_unlock.any? { |name| dependency.root_name == name }
            dependency = Dependency.new(dependency.name)
          end
          dependency_graph.add_child_vertex(dependency.name, parents.empty? ? dependency : nil, parents, nil)
          dependency
        end

        def self.add_to_dependency_graph(object, parents, dependency_graph)
          case object
          when String
            add_child_vertex_to_graph(object, parents, dependency_graph)
          when Hash
            object.each do |key, value|
              dependency = add_child_vertex_to_graph(key, parents, dependency_graph)
              value.each { |v| add_to_dependency_graph(v, [dependency.name], dependency_graph) }
            end
          end
        end
      end
    end
  end
end
