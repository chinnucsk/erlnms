{test,"1.2",{erts,"1.2.3.4"},
	{apps,[{stdlib,"1.2",[{p1,test}]},
	       {kernel,"2.3",[{par,xxxx}]},
	       {myApp,"1.0",[]}]},
	{nodes,[{"node1",[{stdlib,[{p1,prov}]},
			{kernel,[]},
			{myApp,[]}]},
		{"node2",[{stdlib,[{p2,prov}]},
			{kernel,[]}]}
               ]},
	{dist,[{myApp,[node1,{node2}]}]}}.