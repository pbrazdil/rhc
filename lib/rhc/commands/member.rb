require 'rhc/commands/base'

module RHC::Commands
  class Member < Base
    summary "Manage membership on domains"
    syntax "<action>"
    description <<-DESC
      Teams of developers can collaborate on applications by adding people to
      domains as members: each member has a role (admin, editor, or viewer),
      and those roles determine what the user can do with the domain and the
      applications contained within.

      Roles:

        view  - able to see information about the domain and its apps, but not make any changes
        edit  - create, update, and delete applications, and has Git and SSH access
        admin - can update membership of a domain

      The default role granted to members when added is 'edit' - use the '--role'
      argument to use another.  When adding and removing members, you can use their
      'login' value (typically their email or a short unique name for them) or their
      'id'.  Both login and ID are visible via the 'rhc account' command.

      To see existing members of a domain or application, use:

        rhc members -n <domain_name> [-a <app_name>]

      To change the role for a user, simply call the add-member command with the new role. You
      cannot change the role of the owner.
      DESC
    syntax "<action>"
    default_action :help

    summary "List members of a domain or application"
    syntax "<domain_or_app_name> [-n DOMAIN_NAME] [-a APP_NAME]"
    description <<-DESC
      Show the existing members of a domain or application - you can pass the name
      of your domain with '-n', the name of your application with '-a', or combine
      them in the first argument to the command like:

        rhc members <domain_name>/[<app_name>]

      The owner is always listed first.  To see the unique ID of members, pass
      '--ids'.
      DESC
    option ['--ids'], "Display the IDs of each member", :optional => true
    takes_application_or_domain :argument => true
    alias_action :members, :root_command => true
    def list(path)
      target = find_app_or_domain(path)
      members = target.members.sort_by{ |m| [m.owner? ? 0 : 1, m.role_weight, m.name] }
      show_name = members.any?{ |m| m.name && m.name != m.login }
      members.map! do |m|
        [
          ((m.name || "") if show_name),
          m.login || "",
          m.owner? ? "#{m.role} (owner)" : m.role,
          (m.id if options.ids)
        ].compact
      end
      say table(members, :header => [('Name' if show_name), 'Login', 'Role', ("ID" if options.ids)].compact)

      0
    end

    summary "Add or update a member on a domain"
    syntax "<login> [<login>...] [-n DOMAIN_NAME] [--role view|edit|admin] [--ids]"
    description <<-DESC
      Adds or updates members on a domain by passing one or more login
      or ids for other people on OpenShift.  The login and ID values for each
      account are displayed in 'rhc account'. To change the role for a user, simply
      call the add-member command with the new role. You cannot change the role of
      the owner.

      Roles
        view  - able to see information about the domain and its apps,
                but not make any changes
        edit  - create, update, and delete applications, and has Git
                and SSH access
        admin - can update membership of a domain

      The default role granted to members when added is 'edit' - use the '--role'
      argument for 'view' or 'admin'.

      Examples
        rhc add-member sally joe -n mydomain
          Gives the accounts with logins 'sally' and 'joe' edit access on mydomain

        rhc add-member bob@example.com --role admin -n mydomain
          Gives the account with login 'bob@example.com' admin access on mydomain

      DESC
    takes_domain
    option ['--ids'], "Treat the arguments as a list of IDs", :optional => true
    option ['-r', '--role ROLE'], "The role to give to each member - view, edit, or admin (default 'edit')", :type => Role, :optional => true
    argument :members, "A list of members logins to add.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def add(members)
      target = find_domain
      role = options.role || 'edit'
      raise ArgumentError, 'You must pass one or more logins or ids to this command' unless members.present?
      say "Adding #{pluralize(members.length, role_name(role))} to #{target.class.model_name.downcase} ... "
      target.update_members(changes_for(members, role))
      success "done"

      0
    end

    summary "Remove a member from a domain"
    syntax "<login> [<login>...] [-n DOMAIN_NAME] [--ids]"
    description <<-DESC
      Remove members on a domain by passing one or more login or ids for each
      member you wish to remove.  View the list of existing members with
      'rhc members <domain_name>'.

      Pass '--all' to remove all but the owner from the domain.
      DESC
    takes_domain
    option ['--ids'], "Treat the arguments as a list of IDs"
    option ['--all'], "Remove all members from this domain."
    argument :members, "Member logins to remove from the domain.  Pass --ids to treat this as a list of IDs.", [], :type => :list
    def remove(members)
      target = find_domain

      if options.all
        say "Removing all members from #{target.class.model_name.downcase} ... "
        target.delete_members
        success "done"

      else
        raise ArgumentError, 'You must pass one or more logins or ids to this command' unless members.present?
        say "Removing #{pluralize(members.length, 'member')} from #{target.class.model_name.downcase} ... "
        target.update_members(changes_for(members, 'none'))
        success "done"
      end

      0
    end

    protected
      def changes_for(members, role)
        members.map do |m|
          h = {:role => role}
          h[options.ids ? :id : :login] = m
          h
        end
      end
  end
end