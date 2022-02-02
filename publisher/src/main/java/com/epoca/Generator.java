package com.epoca;

import com.google.common.collect.Maps;
import java.io.IOException;
import java.util.Map;
import org.apache.beam.sdk.Pipeline;
import org.apache.beam.sdk.PipelineResult;
import org.apache.beam.sdk.io.GenerateSequence;
import org.apache.beam.sdk.io.gcp.pubsub.PubsubIO;
import org.apache.beam.sdk.io.gcp.pubsub.PubsubMessage;
import org.apache.beam.sdk.options.Description;
import org.apache.beam.sdk.options.PipelineOptions;
import org.apache.beam.sdk.options.PipelineOptionsFactory;
import org.apache.beam.sdk.options.Validation.Required;
import org.apache.beam.sdk.transforms.DoFn;
import org.apache.beam.sdk.transforms.ParDo;
import org.joda.time.Duration;
import java.util.UUID;
import java.time.Instant;

public class Generator {
  public interface Options extends PipelineOptions {
    @Description("The number of elements per second which the generator should output to Pub/Sub.")
    @Required
    Long getQps();

    void setQps(Long value);

    @Description("The topic to which measurements will be published.")
    @Required
    String getTopic();

    void setTopic(String value);
  }

  public static void main(String[] args) {
    Options options = PipelineOptionsFactory.fromArgs(args).withValidation().as(Options.class);

    run(options);
  }

  public static PipelineResult run(Options options) {
    Pipeline pipeline = Pipeline.create(options);

    pipeline
        .apply("Trigger", GenerateSequence.from(0L).withRate(options.getQps(), Duration.standardSeconds(1L)))
        .apply("GenerateMessages", ParDo.of(new MessageGeneratorFn()))
        .apply("WriteToPubsub", PubsubIO.writeMessages().to(options.getTopic()));

    return pipeline.run();
  }

  static class MessageGeneratorFn extends DoFn<Long, PubsubMessage> {
    Long numUsers;

    MessageGeneratorFn() {
    }

    @ProcessElement
    public void processElement(ProcessContext context)
        throws IOException {
      Long index = context.element();

      String eventId = UUID.randomUUID().toString();
      String actorId = UUID.randomUUID().toString();
      String producedAt = Instant.now().toString();
      String messageFormat = "{\"eventId\": \"%s\", \"producedAt\": \"%s\", \"actorId\": \"%s\", \"eventName\": \"myEvent\", \"data\": {\"myInt\": %d}}";
      String jsonMessage = String.format(messageFormat, eventId, producedAt, actorId, index);
      byte[] payload = jsonMessage.getBytes();

      Map<String, String> attributes = Maps.newHashMap();
      PubsubMessage message = new PubsubMessage(payload, attributes);

      context.output(message);
    }
  }
}
