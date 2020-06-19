require "active_support/core_ext/class/attribute"

module Commands
  class Base
    class_attribute :attr_names
    class_attribute :step_names
    class_attribute :validation_contract
    class_attribute :error_handler
    class_attribute :transaction_on

    class << self
      def run(*args)
        new(*args).run
      end

      def params(*args)
        self.attr_names ||= []

        args.each do |attr_name|
          attr_reader attr_name
          self.attr_names += [attr_name]
        end
      end

      def attrs(*args)
        args.each do |attr_name|
          attr_accessor attr_name
        end
      end

      def step(step_name)
        self.step_names ||= []

        self.step_names += [step_name]
      end

      def steps(*step_names)
        step_names.each do |step_name|
          step(step_name)
        end
      end

      def error(error_handler_name)
        self.error_handler = error_handler_name
      end

      def transaction(attribute_name)
        self.transaction_on = attribute_name
      end
    end

    def initialize(*args, **named_args)
      self.class.attr_names.each_with_index do |attr_name, i|
        set_attribute(attr_name, args[i])
      end

      named_args.each do |key, val|
        set_attribute(key, val)
      end

      init if respond_to?(:init, true)
      validate if respond_to?(:validate, true)

      validate!
    end

    def run
      tap { CommandProcessor.new.process!(self) }
    end

    def execute(metadata:)
      catch :stop_steps do
        if transaction_on
          method(transaction_on).call.transaction do
            log "Running all steps in a transaction on #{transaction_on}"

            execute_steps

            log "Committing transaction on #{transaction_on}"
          end
        else
          execute_steps
        end
      end
    end

    def execute_steps
      step_names.each do |step_name|
        log "Running step :#{step_name}"
        run_step(step_name)
        log "Step :#{step_name} completed successfully"
      rescue => e
        log "Step :#{step_name} failed with #{e.message}"

        method(error_handler).call(e) if error_handler.present?
        raise
      end

      self
    end

    def run_step(step_name)
      method(step_name).call
    end

    def continue?
      @continue
    end

    def stop!(message = nil)
      log "Stopping command execution because stop! was called. Message: #{message}."
      throw :stop_steps
    end

    def validate!
      return if valid?

      raise ValidationError, validate_schema.errors
    end

    def validate_schema
      return unless validation_contract

      validation_contract
        .call(command_attributes)
        .tap { |result| assign_attributes(result.to_h) }
    end

    def valid?
      return true unless validation_contract

      validate_schema.success?
    end

    def command_attributes
      self.class.attr_names.map { |attr_name|
        [attr_name, public_send(attr_name)]
      }.to_h
    end

    # Define a validation
    # See: dry-validation
    def self.validation(&block)
      self.validation_contract = Dry::Schema.JSON do
        instance_eval(&block)
      end
    end

    class Error < RuntimeError; end
    class ValidationError < Error
      def initialize(validation_errors)
        @validation_errors = validation_errors
      end

      def to_s
        @validation_errors.inspect
      end
    end

    private

    def set_attribute(key, val)
      instance_variable_set("@#{key}", val)
    end

    def assign_attributes(hash)
      self.attr_names.each do |attr_name|
        set_attribute(attr_name, hash[attr_name]) if hash.has_key?(attr_name)
      end
    end

    def log(message, level: :info)
      @logger ||= Rails.logger

      @logger.tagged("Command", self.class.name) do |logger|
        logger.method(level).call(message)
      end
    end
  end
end
