var Modal = require("views/core/modal")

describe("Modal", function() {

	var m, el, options;

	beforeEach(function() {
	  m = new Modal();
	  el = m.$el;
	  options = {
			title: "Test Title",
			message: "Test Message",
			success: jasmine.createSpy('dummySuccess'),
			error: jasmine.createSpy('dummyError')
		}
	})

  it("should extend View", function() {
    expect(m instanceof View).toBe(true);
  });

  describe("#show", function() {
  	m.show(options);
  	console.log(m.el.innerHTML)

    it("should display a title", function() {
	    expect(el.find(".title").html()).toEqual(options.title);
	  });

    it("should display a message", function() {
	    expect(el.find(".message").html()).toEqual(options.message);
	  });
  });

  describe("#onSuccess", function() {
  	m.onSuccess()

  	it("should run the success callbacks", function() {
  		expect(options.success).toHaveBeenCalled()
  	});

  	it("should not run the error callbacks", function() {
  		expect(options.error).not.toHaveBeenCalled()
  	});
  });

  describe("#onCancel", function() {
  	m.onCancel()

  	it("should not run the success callbacks", function() {
  		expect(options.success).not.toHaveBeenCalled()
  	});

  	it("should run the error callbacks", function() {
  		expect(options.error).toHaveBeenCalled()
  	});
  });

});
