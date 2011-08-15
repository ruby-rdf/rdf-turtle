require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::Turtle::Format do
  context "discovery" do
    {
      "etc/foaf.ttl" => RDF::Format.for("etc/foaf.ttl"),
      "foaf.ttl" => RDF::Format.for(:file_name      => "foaf.ttl"),
      ".ttl" => RDF::Format.for(:file_extension => "ttl"),
      "text/turtle" => RDF::Format.for(:content_type   => "text/turtle"),
      "application/turtle" => RDF::Format.for(:content_type   => "application/turtle"),
      "application/x-turtle" => RDF::Format.for(:content_type   => "application/x-turtle"),
    }.each_pair do |label, format|
      it "should discover '#{label}'" do
        format.should == RDF::Turtle::Format
      end
    end
    
    it "should discover 'turtle'" do
      RDF::Format.for(:turtle).reader.should == RDF::Turtle::Reader
      RDF::Format.for(:turtle).writer.should == RDF::Turtle::Writer
    end
    
    it "should discover 'ttl'" do
      RDF::Format.for(:ttl).reader.should == RDF::Turtle::Reader
      RDF::Format.for(:ttl).writer.should == RDF::Turtle::Writer
    end
  end
end
