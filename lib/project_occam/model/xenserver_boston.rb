# Root ProjectOccam namespace
module ProjectOccam
  module ModelTemplate
    # Root Model object
    # @abstract
    class XenServerBoston < ProjectOccam::ModelTemplate::XenServer

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "xenserver_boston"
        @description = "Citrix XenServer 6.0 (boston) Deployment"
        @osversion = "boston"
        from_hash(hash) unless hash == nil
      end
    end
  end
end

