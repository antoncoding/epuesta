let request = require('request');

/**
 * Get specific match detail
 * @param {{body:{data:{match_id:string}, id:string}}} req
 **/
exports.matchAdapter = (req, res) => {
  const footballApiKey = "15fe3e60cc53879ea6ab6a0964838e35ae7565cc2a16e4dbce6289bd4dbd85d9"
  const match_id = req.body.data.match_id || "";
  const url = `https://apiv2.apifootball.com/action=get_events&match_id=${match_id}&APIkey=$${footballApiKey}`;
 
  let options = {
      url: url,
      json: true
  };

  request(options, (error, response, body) => {
    if (error || response.statusCode >= 400) {
        let errorData = {
            jobRunID: req.body.id,
            status: "errored",
            error: body
        };
        res.status(response.statusCode).send(errorData);
    } else {
      let returnData = {
        jobRunID: req.body.id,
        data: body[0],
      };
      res.status(response.statusCode).send(returnData);
    }
  });
};